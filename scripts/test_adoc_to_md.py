
import subprocess
from pathlib import Path
import re

def test_front_matter_created():
    adoc = 'ru/modules/ROOT/pages/p2-120-school.adoc'
    md = 'text/ru/p2-120-school.md'
    failures = []
    # Run the conversion script
    subprocess.run([
        'python', 'scripts/adoc_to_md.py', adoc, md
    ], check=True)
    # Check the output file for the correct front matter
    with open(md, encoding='utf-8') as f:
        content = f.read()
    # Check that the line 'what**is**happiness' does NOT appear in the output
    if 'what**is**happiness' in content:
        failures.append("Output .md file should not contain the line 'what**is**happiness'")
    if 'brief*happiness*model' in content:
        failures.append("Output .md file should not contain the line 'brief*happiness*model'")
    # Check for a line with no indent after the sidebar
    if '\nКогда аморфные понятия начинают обретать структуру в голове, следом возникает вопрос о возможности измерений параметров этой структуры.\n' not in content:
        failures.append('Expected non-indented line missing in output .md file')
    if 'created: 19.06.2023' not in content:
        failures.append('Front Matter missing correct created date')
    if ':created-date:' in content:
        failures.append('Output .md file should not contain :created-date:')
    if '## Количественные модели в управлении {#models_in_history}' not in content:
        failures.append('Heading with anchor missing in output .md file')
    with open('scripts/fixtures/sidebar_block.md', encoding='utf-8') as f:
        sidebar_block = f.read()
    if sidebar_block not in content:
        failures.append('Sidebar block with title and indented content missing or incorrect in output .md file')
    with open('scripts/fixtures/quote_block.md', encoding='utf-8') as f:
        quote_block = f.read()
    if quote_block not in content:
        failures.append('Quote block with title and indented content missing or incorrect in output .md file')
    with open('scripts/fixtures/quote_block_url.md', encoding='utf-8') as f:
        quote_block_url = f.read()
    if quote_block_url not in content:
        failures.append('Quote block with title, author, url and indented content missing or incorrect in output .md file')
    if 'Пожалуй, в xref:p2-110-system.adoc#rational_definition_of_christ[ещё более жесткой конкурентной системе координат пребывает внешняя политика].' in content:
        failures.append('Output .md file should not contain AsciiDoc xref link with .adoc.')
    # Check that AsciiDoc xref link is not present in the output
    if 'xref:' in content:
        failures.append('Output .md file should not contain AsciiDoc xref link.')

    # Check for author italic line
    author_line_expected = '*Автор текста: ([Владимир Андреев](p2-100-authors.md#andreevvs))*'
    found = False
    for line in content.splitlines():
        if line == author_line_expected:
            found = True
    if not found:
        failures.append('Italic author line missing in output .md file')
    # Check for link to anchor in another file (should be Markdown, not xref)
    expected_crossfile = 'Лучше осознаёшь [влияние зависимостей от модификаторов состояния](p1-030-time.md#awareness_and_addictions).'
    if expected_crossfile not in content:
        failures.append('Link to anchor in another file missing in output .md file')

    # Check for image block with caption
    with open('scripts/fixtures/image_block.md', encoding='utf-8') as f:
        image_block = f.read()
    if image_block not in content:
        failures.append('Image block with caption missing or incorrect in output .md file')

    # Check for string with underscores in URL
    expected_string = 'в какой-то момент отступит благодаря'
    if expected_string not in content:
        failures.append(f"Expected string '{expected_string}' missing in output .md file")

    if failures:
        print('\nTEST FAILURES:')
        for fail in failures:
            print('-', fail)
        print(f"\n{len(failures)} test(s) failed.")
        exit(1)
    else:
        print('All tests passed.')

if __name__ == '__main__':
    test_front_matter_created()
