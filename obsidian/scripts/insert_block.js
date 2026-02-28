module.exports = async function (tp) {
  
  const blockTypes = [
    { label: 'quote — цитата с автором',             type: 'quote'     },
    { label: 'situation — ситуация из жизни',        type: 'situation' },
    { label: 'abstract — пример / анекдот / притча', type: 'abstract'  },
    { label: 'define — термин и определение',        type: 'define'    },
    { label: 'rule — правило / принцип',             type: 'rule'      },
    { label: 'music — музыкальная вставка',          type: 'music'     },
    { label: 'details — сворачиваемый блок',         type: 'details'   },
  ];  
  
  const choice = await tp.system.suggester(
    blockTypes.map(b => b.label),
    blockTypes
  );  
  
  const selection = tp.file.selection();
  const text = selection && selection.trim() ? selection.trim() : 'Текст';

  if (!choice) return '';
  switch (choice.type) {
    
    case 'quote': {
      const quoteText = await tp.system.prompt('Текст цитаты', text);
      if (!quoteText) return '';
      const author = await tp.system.prompt('Автор', 'Автор цитаты');
      const source = await tp.system.prompt('URL источника (необязательно)', 'https://');
      const authorLine = author && source  ? `[${author}](${source}){ .author }`
                       : author            ? `${author}{ .author }`
                       : '';
      return authorLine
        ? `/// quote\n\n${quoteText}\n\n${authorLine}\n\n///`
        : `/// quote\n\n${quoteText}\n\n///`;
    }
  
    case 'situation': {
      return `/// situation\n\n${text}\n\n///`;
    }
  
    case 'abstract': {
      const title = await tp.system.prompt('Заголовок');
      if (!title) return '';
      return `/// abstract | ${title}\n\n${text}\n\n///`;
    }  

    case 'define': {
      const term = await tp.system.prompt('Термин', 'Термин');
      if (!term) return '';
      const definition = await tp.system.prompt('Определение', 'Определение');
      if (!definition) return '';
      return `/// define\n\n${term}\n\n- ${definition}\n\n///`;
    }  

    case 'rule': {
      return `/// rule\n\n${text}\n\n///`;
    }

    case 'music': {
      return `/// music\n\n${text}\n\n///`;
    }

    case 'details': {
      return `/// details\n\n\`\`\`\n${text}\n\`\`\`\n\n///`;
    }

    default:
      return '';
  }
};
