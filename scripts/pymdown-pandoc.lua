-- Pandoc Lua filter - convert PyMdown blocks to Pandoc Divs
--
-- Converts /// block-type | caption ... /// to ::: block-type ... :::
-- Handles nested blocks recursively
-- Special handling for image caption blocks

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
          pending_key = text:sub(1, -2)
        elseif text:match("^[a-z_%-]+=[a-z_%-]+$") then
          local key, val = text:match("^([a-z_%-]+)=([a-z_%-]+)$")
          if key and val then
            new_attributes[key] = val
          end
        end
      end
    elseif elem.t == 'Quoted' and in_braces and pending_key ~= "" then
      local quoted_val = pandoc.utils.stringify(elem.c)
      new_attributes[pending_key] = quoted_val
      pending_key = ""
    end
    
    i = i + 1
  end
  
  return new_attributes
end

-- Process images: extract attributes and keep only width/height
function Para(para)
  if not para.c or #para.c < 1 or para.c[1].t ~= 'Image' then
    return nil
  end
  
  local img = para.c[1]
  local attr = img.attr or pandoc.Attr()
  
  -- Extract attributes from following elements
  local new_attributes = extract_image_attributes(para, 2)
  
  -- Merge new attributes
  if next(new_attributes) then
    for k, v in pairs(new_attributes) do
      attr.attributes[k] = v
    end
  end
  
  -- Keep only width and height
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
    attr = pandoc.Attr()
  end
  
  return pandoc.Para{pandoc.Image(img.caption, img.src, pandoc.utils.stringify(img.caption), attr)}
end

-- Convert /// blocks to Pandoc Divs
-- Handles: /// block-type | caption ... ///
-- Output: ::: {.block-type caption="caption text"} ... :::
-- Helper: stringify inlines preserving soft breaks as newlines
local function inlines_to_text(inlines)
  local buf = {}
  for _, el in ipairs(inlines) do
    if el.t == 'Str' then
      table.insert(buf, el.text or '')
    elseif el.t == 'Space' then
      table.insert(buf, ' ')
    elseif el.t == 'SoftBreak' or el.t == 'LineBreak' then
      table.insert(buf, '\n')
    elseif el.t == 'Code' then
      table.insert(buf, el.text or '')
    elseif el.t == 'Quoted' then
      table.insert(buf, pandoc.utils.stringify(el.c))
    else
      -- ignore other inline types for our purposes
    end
  end
  return table.concat(buf)
end
function Blocks(blocks)
  local result = {}
  local i = 1
  
  while i <= #blocks do
    local block = blocks[i]
    
    -- Check for /// block markers: Para starting with "///"
    if block.t == 'Para' and block.c[1] and block.c[1].t == 'Str' then
      local first_text = block.c[1].text or ""
      
      -- Opening marker: "///" followed by block-type
      if first_text:match("^///") then
        -- Support condensed syntax where opening, content, and closing are within one paragraph:
        --   /// type\ncontent\n///
        -- Extract full paragraph text with preserved soft breaks
        local para_text = inlines_to_text(block.c)
        -- Split into lines
        local lines = {}
        for line in (para_text .. "\n"):gmatch("([^\n]*)\n") do
          table.insert(lines, line)
        end
        -- Try to find a closing marker within the same paragraph
        local handled_inline = false
        if #lines >= 2 and lines[1]:match("^///") then
          local close_idx = nil
          for idx = 2, #lines do
            if lines[idx]:match("^%s*///%s*$") then
              close_idx = idx
              break
            end
          end
          if close_idx then
            local opening_line = lines[1]
            local block_type_inline, caption_inline = opening_line:match("^///[%s]*([^%s|]+)[%s]*|?[%s]*(.*)")
            if block_type_inline and block_type_inline ~= '' then
              -- Gather content between opening and closing lines
              local content_lines = {}
              for idx = 2, close_idx - 1 do
                table.insert(content_lines, lines[idx])
              end
              local content_text = table.concat(content_lines, "\n")
              -- Parse content as markdown, then recursively process blocks/images
              local parsed_doc = pandoc.read(content_text, "markdown")
              parsed_doc = parsed_doc:walk({ Blocks = Blocks, Para = Para })
              
              -- If caption present, prepend as h6 heading
              if caption_inline and caption_inline ~= "" then
                local caption_heading = pandoc.Header(6, pandoc.Str(caption_inline))
                caption_heading.attr = pandoc.Attr("", {"block-caption"}, {})
                table.insert(parsed_doc.blocks, 1, caption_heading)
              end
              
              -- Build Div with class
              local attr = pandoc.Attr("", { block_type_inline }, {})
              local div = pandoc.Div(parsed_doc.blocks, attr)
              table.insert(result, div)
              i = i + 1
              handled_inline = true
            end
          end
        end
        if handled_inline then
          -- processed condensed block; continue loop
        else
        -- Extract block type and optional caption from the opening line
        -- Format: /// block-type | caption text
        local opening_line = pandoc.utils.stringify(block.c)
        local block_type, caption = opening_line:match("^///[%s]*([^%s|]+)[%s]*|?[%s]*(.*)")
        
        if not block_type then
          -- No block type found, treat as plain paragraph
          table.insert(result, block)
          i = i + 1
        else
          -- Collect content blocks until closing "///"
          local content_blocks = {}
          local j = i + 1
          local found_closing = false
          
          while j <= #blocks do
            local content_block = blocks[j]
            
            -- Check for closing marker
            if content_block.t == 'Para' and 
               content_block.c[1] and 
               content_block.c[1].t == 'Str' and
               content_block.c[1].text == "///" then
              found_closing = true
              break
            end
            
            table.insert(content_blocks, content_block)
            j = j + 1
          end
          
          if found_closing then
            -- Recursively process content blocks (handles nesting)
            content_blocks = Blocks(content_blocks)
            
            -- If caption present, prepend as h6 heading
            if caption and caption ~= "" then
              local caption_heading = pandoc.Header(6, pandoc.Str(caption))
              caption_heading.attr = pandoc.Attr("", {"block-caption"}, {})
              table.insert(content_blocks, 1, caption_heading)
            end
            
            -- Create Pandoc Div with class
            local attr = pandoc.Attr("", {block_type}, {})
            local div = pandoc.Div(content_blocks, attr)
            table.insert(result, div)
            
            -- Skip to after closing marker
            i = j + 1
          else
            -- No closing found, treat as plain paragraph
            table.insert(result, block)
            i = i + 1
          end
        end
        end
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
