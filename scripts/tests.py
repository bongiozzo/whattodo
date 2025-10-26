#!/usr/bin/env python3
"""
Tests using fixture files to verify build output.
"""

import os
import pytest
from pathlib import Path

# Get build paths from environment (set by Makefile) with sensible defaults
REPO_ROOT = Path(__file__).parent.parent
COMBINED_MD = REPO_ROOT / os.getenv('COMBINED_MD', 'build/text_combined.txt')
PANDOC_MD = REPO_ROOT / os.getenv('PANDOC_MD', 'build/pandoc.md')

class TestFixtures:
    """Tests that verify fixture content in build output"""

    @staticmethod
    def _check_fixture_in_output(fxt_name, output_file):
        """Helper: Check if fixture content is in output file"""
        fxt_path = Path(__file__).parent / "fixtures" / fxt_name
        output_path = Path(output_file) if isinstance(output_file, Path) else REPO_ROOT / output_file

        if not fxt_path.exists():
            pytest.skip(f"{fxt_name} fixture not found")
        if not output_path.exists():
            pytest.skip(f"{output_path.name} not generated; run 'make' first")

        fxt_content = fxt_path.read_text(encoding="utf-8").strip()
        output_content = output_path.read_text(encoding="utf-8")

        assert fxt_content in output_content, \
            f"{fxt_name} not found in {output_path.name}"

    def test_combined_heading(self):
        """Verify combined heading fixture in combined.md"""
        self._check_fixture_in_output("ptn_combined_heading.md", COMBINED_MD)

    def test_combined_dates(self):
        """Verify combined dates end fixture in combined.md"""
        self._check_fixture_in_output("ptn_combined_dates.md", COMBINED_MD)

    def test_pandoc_dates(self):
        """Verify combined dates end fixture in combined.md"""
        self._check_fixture_in_output("ptn_pandoc_dates.md", PANDOC_MD)

    def test_lua_admonition(self):
        """Verify lua_admonition.md fixture in pandoc.md"""
        self._check_fixture_in_output("ptn_lua_admonition.md", PANDOC_MD)

    def test_lua_image(self):
        """Verify lua_image.md fixture in pandoc.md"""
        self._check_fixture_in_output("ptn_lua_image.md", PANDOC_MD)

    def test_lua_author(self):
        """Verify lua_author.md fixture (underlined link) in pandoc.md"""
        self._check_fixture_in_output("ptn_lua_author.md", PANDOC_MD)

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
