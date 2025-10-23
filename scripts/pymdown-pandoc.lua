-- Pandoc Lua filter - convert PyMdown admonitions and format images

-- Extract image attributes from markdown syntax { width="75%", loading=lazy }
local function extract_image_attributes(para, start_index)
  local new_attributes = {}
  local i = start_index
  local in_braces = false
  local pending_key = ""
  
  while i <= #para.c do
    local elem = para.c[i]
    
    if elem.t == 'Str' then
      local text = elem.text or ""
      
      if text == "{" then
        in_braces = true
      elseif text == "}" then
        in_braces = false
        break
      elseif in_braces then
        if text:match("=$") then
          -- Key ending with =, like "width="
          pending_key = text:sub(1, -2)
        elseif text:match("^[a-z_%-]+=[a-z_%-]+$") then
          -- Full attribute like "loading=lazy"
          local key, val = text:match("^([a-z_%-]+)=([a-z_%-]+)$")
          if key and val then
            new_attributes[key] = val
          end
        end
      end
    elseif elem.t == 'Quoted' and in_braces and pending_key ~= "" then
      -- Quoted value follows pending key
      local quoted_val = pandoc.utils.stringify(elem.c)
      new_attributes[pending_key] = quoted_val
      pending_key = ""
    end
    
    i = i + 1
  end
  
  return new_attributes
end

-- Process images: extract attributes and handle captions
function Para(para)
  -- Check if para contains Image element
  if not para.c or #para.c < 1 or para.c[1].t ~= 'Image' then
    return nil
  end
  
  local img = para.c[1]
  local src = img.src
  local caption_text = pandoc.utils.stringify(img.caption)
  local attr = img.attr or pandoc.Attr()
  
  -- Extract attributes from following elements
  local new_attributes = extract_image_attributes(para, 2)
  
  -- Update image attributes if we found any
  if next(new_attributes) then
    for k, v in pairs(new_attributes) do
      attr.attributes[k] = v
    end
  end
  
  -- Keep only width and height attributes; drop everything else
  do
    local kept = {}
    if attr and attr.attributes then
      for k, v in pairs(attr.attributes) do
        if k == 'width' or k == 'height' then
          kept[k] = v
        end
      end
    end
    if next(kept) then
      attr.attributes = kept
    else
      -- No allowed attributes left: remove attribute block entirely
      attr = pandoc.Attr()
    end
  end
  
  -- Return modified image in a paragraph
  return pandoc.Para{pandoc.Image(
    img.caption,
    src,
    caption_text,
    attr
  )}
end

-- Convert PyMdown admonitions to BlockQuotes (recursive)
function Blocks(blocks)
  local result = {}
  local i = 1
  
  while i <= #blocks do
    local block = blocks[i]
    
    -- Check if this is an admonition marker: Para starting with !!!
    if block.t == 'Para' and 
       block.c[1] and block.c[1].t == 'Str' and block.c[1].text == '!!!' and
       block.c[2] and block.c[2].t == 'Space' and
       block.c[3] and block.c[3].t == 'Str' then
      
      -- Check if next block is CodeBlock (the content)
      if i + 1 <= #blocks and blocks[i + 1].t == 'CodeBlock' then
        local admon_type = block.c[3].text  -- e.g., "note"
        local title = ""
        
        -- Extract title from Quoted element if present
        if block.c[5] and block.c[5].t == 'Quoted' then
          title = pandoc.utils.stringify(block.c[5].c)
        end
        
        -- Get the CodeBlock content and parse as markdown
        local content_text = blocks[i + 1].text or ""
        local parsed_doc = pandoc.read(content_text, "markdown")
        
        -- Recursively process the parsed content (handles nested admonitions and images)
        parsed_doc = parsed_doc:walk({
          Blocks = Blocks,
          Para = Para
        })

        -- If this is a quote admonition, make all inline content italic
        if admon_type == 'quote' then
          parsed_doc = parsed_doc:walk({
            Inlines = function(inlines)
              return {pandoc.Emph(inlines)}
            end
          })
        end

        -- Create BlockQuote with title and processed content blocks
        local title_para = pandoc.Para(pandoc.Strong(title))
        local quote_blocks = {title_para}

        -- Add all processed blocks to the quote
        for _, content_block in ipairs(parsed_doc.blocks) do
          table.insert(quote_blocks, content_block)
        end

        table.insert(result, pandoc.BlockQuote(quote_blocks))

        -- Skip both blocks (Para marker and CodeBlock content)
        i = i + 2
      else
        table.insert(result, block)
        i = i + 1
      end
    else
      table.insert(result, block)
      i = i + 1
    end
  end
  
  return result
end
