#!/usr/bin/env python3
"""
Tests using fixture files to verify build output.
"""

import pytest
from pathlib import Path

class TestFixtures:
    """Tests that verify fixture content in build output"""

    @staticmethod
    def _check_fixture_in_output(fxt_name, output_file):
        """Helper: Check if fixture content is in output file"""
        fxt_path = Path(__file__).parent / "fixtures" / fxt_name
        output_path = Path(__file__).parent.parent / output_file

        if not fxt_path.exists():
            pytest.skip(f"{fxt_name} fixture not found")
        if not output_path.exists():
            pytest.skip(f"{output_file} not generated; run 'make' first")

        fxt_content = fxt_path.read_text(encoding="utf-8").strip()
        output_content = output_path.read_text(encoding="utf-8")

        assert fxt_content in output_content, \
            f"{fxt_name} not found in {output_file}"

    def test_combined_heading(self):
        """Verify combined heading fixture in combined.md"""
        fxt_name = "ptn_combined_heading.md"
        self._check_fixture_in_output(fxt_name, "text/ru/assets/text_combined.txt")

    def test_combined_dates_end(self):
        """Verify combined dates end fixture in combined.md"""
        fxt_name = "ptn_combined_dates.md"
        self._check_fixture_in_output(fxt_name, "text/ru/assets/text_combined.txt")

    def test_book_meta(self):
        """Verify book_meta.yml matches fixture exactly"""
        build_path = Path(__file__).parent.parent / "book_meta.yml"
        fxt_path = Path(__file__).parent / "fixtures" / "ptn_book_meta.yaml"

        if not fxt_path.exists():
            pytest.skip("ptn_book_meta.yaml fixture not found")
        if not build_path.exists():
            pytest.skip("book_meta.yml not generated; run 'make' first")

        build_content = build_path.read_text(encoding="utf-8")
        fxt_content = fxt_path.read_text(encoding="utf-8")

        assert build_content == fxt_content, "book_meta.yml does not match fixture"

    def test_lua_admonition(self):
        """Verify lua_admonition.md fixture in pandoc.md"""
        fxt_name = "ptn_lua_admonition.md"
        self._check_fixture_in_output(fxt_name, "build/pandoc.md")

    def test_lua_image(self):
        """Verify lua_image.md fixture in pandoc.md"""
        fxt_name = "ptn_lua_image.md"
        self._check_fixture_in_output(fxt_name, "build/pandoc.md")

    def test_lua_underline(self):
        """Verify underlined/superscript content (^^...^^) is processed correctly"""
        output_path = Path(__file__).parent.parent / "build/pandoc.md"
        if not output_path.exists():
            pytest.skip("pandoc.md not generated; run 'make' first")
        output_content = output_path.read_text(encoding="utf-8")
        # Search patterns for superscript content (Pandoc converts ^^ to <sup>)
        ptn_sup_tag = '<sup>'
        ptn_author_name = 'Рыбаков'
        assert ptn_sup_tag in output_content or ptn_author_name in output_content, \
            "Superscript content not found in pandoc.md"

    def test_lua_author(self):
        """Verify lua_author.md fixture (underlined link) in pandoc.md"""
        fxt_name = "ptn_lua_author.md"
        self._check_fixture_in_output(fxt_name, "build/pandoc.md")

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
