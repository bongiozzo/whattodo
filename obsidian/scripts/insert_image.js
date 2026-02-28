module.exports = async function (tp) {

  const selection = tp.file.selection();
  const text = selection && selection.trim() ? selection.trim() : 'Надпись';
  const caption = await tp.system.prompt('Надпись', text);

  const source = await tp.system.prompt('URL изображения', 'img/');
  return `![${caption}](${source}){ width="100%", loading=lazy }\n/// caption\n\n${caption}\n\n///`

};
