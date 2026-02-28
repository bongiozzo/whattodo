module.exports = async function (tp) {

  const files = app.vault.getMarkdownFiles().filter(f => f.path.startsWith('text/'));
  
  const entries = [];
  for (const f of files) {
    const content = await app.vault.read(f);
    const regex = /^(#+)\s+(.+?)\s+\{#(\w+)\}/gm;
    let m;
    while ((m = regex.exec(content)) !== null) {
      entries.push({
        display: `${m[2]} → ${f.basename}#${m[3]}`,
        file: f.basename,
        id: m[3],
        title: m[2]
      });
    }
  }

  const choice = await tp.system.suggester(
    entries.map(e => e.display),
    entries
  );
  
  if (choice) {
    return `[${choice.title}](${choice.file}.md#${choice.id})`;
  }
  return '';
};