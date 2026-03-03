/*
 * text-forge - Obsidian plugin
 *
 * Resolves {#anchor-id} heading anchors (attr_list syntax: ## Title {#custom-id})
 * Obsidian ignores {#id}, so [[file#custom-id]] opens the file but doesn't scroll.
 *
 * This plugin fixes that for both view modes:
 *   - Live Preview / Source  → editor.scrollIntoView(line)
 *   - Reading view           → incremental scrollTop scan to materialise lazy-
 *                              rendered content, then precise offsetTop snap
 *
 * It also strips {#id} from rendered heading text and data-heading in Reading view.
 */

'use strict';

const { Plugin, MarkdownView } = require('obsidian');

// Matches trailing MkDocs anchor syntax, e.g. " {#some-id}"
const ANCHOR_RE = /\s*\{#([\w-]+)\}\s*$/;

// Reading-view scroll tuning
const SCAN_STEPS       = 60;   // max incremental steps
const SCAN_INTERVAL_MS = 30;   // ms between steps  (total worst-case: ~1.8 s)
const SCAN_OVERSHOOT   = 1.4;  // scan up to fraction * OVERSHOOT in case images push content down
const SCAN_PRE_MARGIN  = 0.08; // start this fraction before the line estimate
const SCROLL_PADDING   = 40;   // px above heading after final snap
const FILE_OPEN_DELAY  = 300;  // ms to wait after file-open before acting

class MkDocsAnchorsPlugin extends Plugin {
  async onload() {
    this._pendingAnchor = null;
    this._patchOpenLinkText();
    this.registerMarkdownPostProcessor(el => this._cleanHeadings(el));
    this.registerEvent(this.app.workspace.on('file-open', f => this._onFileOpen(f)));
  }

  // ── openLinkText patch ────────────────────────────────────────────────────

  _patchOpenLinkText() {
    const ws = this.app.workspace;
    const orig = ws.openLinkText.bind(ws);
    ws.openLinkText = async (linktext, sourcePath, newLeaf, openViewState) => {
      const hash = (linktext || '').indexOf('#');
      this._pendingAnchor = hash !== -1 ? linktext.slice(hash + 1) : null;
      return orig(linktext, sourcePath, newLeaf, openViewState);
    };
    this.register(() => { ws.openLinkText = orig; });
  }

  // ── Reading-view post-processor ───────────────────────────────────────────

  /** Set id= on headings and strip {#id} from visible text + data-heading. */
  _cleanHeadings(el) {
    el.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(h => {
      const match = (h.textContent || '').match(ANCHOR_RE);
      if (!match) return;
      h.id = match[1];
      const dh = h.getAttribute('data-heading');
      if (dh) h.setAttribute('data-heading', dh.replace(ANCHOR_RE, '').trim());
      h.childNodes.forEach(node => {
        if (node.nodeType === Node.TEXT_NODE)
          node.textContent = node.textContent.replace(ANCHOR_RE, '');
      });
    });
  }

  // ── file-open handler ────────────────────────────────────────────────────

  _onFileOpen(file) {
    if (!file || !this._pendingAnchor) return;
    const anchor = this._pendingAnchor;
    const view = this.app.workspace.getActiveViewOfType(MarkdownView);
    if (!view) return;

    setTimeout(() => this._scrollToAnchor(file, anchor, view), FILE_OPEN_DELAY);
  }

  async _scrollToAnchor(file, anchor, view) {
    const lineIdx = await this._findAnchorLine(file, anchor);
    if (lineIdx === -1) return;
    this._pendingAnchor = null;

    if (view.getMode() === 'source') {
      this._scrollEditor(view, lineIdx);
    } else {
      this._scrollReadingView(view, anchor, lineIdx, await this._lineCount(file));
    }
  }

  // ── Source / Live Preview scroll ─────────────────────────────────────────

  _scrollEditor(view, lineIdx) {
    view.editor?.scrollIntoView(
      { from: { line: lineIdx, ch: 0 }, to: { line: lineIdx, ch: 0 } },
      true
    );
  }

  // ── Reading-view scroll ──────────────────────────────────────────────────

  /**
   * Obsidian's Reading view uses a virtual/lazy renderer — content far from
   * the viewport isn't in the DOM. We materialise it by incrementally advancing
   * scrollTop, checking for the target heading at each step, then snapping.
   */
  _scrollReadingView(view, anchor, lineIdx, totalLines) {
    const scroller = this._getScroller(view);
    const fraction = lineIdx / Math.max(totalLines - 1, 1);
    const startFrac = Math.max(0, fraction - SCAN_PRE_MARGIN);
    const stepSize  = (fraction * SCAN_OVERSHOOT - startFrac) / SCAN_STEPS;
    let step = 0;

    const scan = () => {
      const frac = Math.min(1, startFrac + step * stepSize);
      scroller.scrollTop = Math.round(frac * scroller.scrollHeight);

      const target = this._findInDom(view, anchor);
      if (target) {
        this._snapToTarget(scroller, target);
        return;
      }
      step++;
      if (step <= SCAN_STEPS) setTimeout(scan, SCAN_INTERVAL_MS);
    };

    scan();
  }

  _snapToTarget(scroller, target) {
    let offsetTop = 0;
    let el = target;
    while (el && el !== scroller) { offsetTop += el.offsetTop; el = el.offsetParent; }
    scroller.scrollTop = offsetTop - SCROLL_PADDING;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  _getScroller(view) {
    return view.contentEl.querySelector('.markdown-preview-view')
        || view.contentEl.querySelector('.markdown-reading-view')
        || view.contentEl;
  }

  _findInDom(view, anchor) {
    return view.contentEl.querySelector('#' + CSS.escape(anchor))
        || view.contentEl.querySelector(`[data-heading*="{#${anchor}}"]`);
  }

  async _findAnchorLine(file, anchor) {
    const text = await this.app.vault.read(file);
    return text.split('\n').findIndex(l => l.includes(`{#${anchor}}`));
  }

  async _lineCount(file) {
    const text = await this.app.vault.read(file);
    return text.split('\n').length;
  }
}

module.exports = MkDocsAnchorsPlugin;
