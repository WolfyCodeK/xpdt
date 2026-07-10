xplr.config.node_types.extension = xplr.config.node_types.extension or {}
xplr.config.node_types.special = xplr.config.node_types.special or {}

xplr.config.node_types.directory = { meta = { icon = "\27[38;2;96;160;255m\27[0m " }, style = { fg = { Rgb = { 96, 160, 255 } }, add_modifiers = { "Bold" } } }
xplr.config.node_types.file = { meta = { icon = "\27[38;2;150;160;175m\27[0m " }, style = { fg = { Rgb = { 150, 160, 175 } } } }
xplr.config.node_types.symlink = { meta = { icon = "\27[38;2;120;220;232m\27[0m " }, style = { fg = { Rgb = { 120, 220, 232 } }, add_modifiers = { "Italic" } } }

xplr.config.node_types.extension["py"] = { meta = { icon = "\27[38;2;255;208;60m\27[0m " }, style = { fg = { Rgb = { 255, 208, 60 } } } }
xplr.config.node_types.extension["js"] = { meta = { icon = "\27[38;2;240;219;79m\27[0m " }, style = { fg = { Rgb = { 240, 219, 79 } } } }
xplr.config.node_types.extension["mjs"] = { meta = { icon = "\27[38;2;240;219;79m\27[0m " }, style = { fg = { Rgb = { 240, 219, 79 } } } }
xplr.config.node_types.extension["cjs"] = { meta = { icon = "\27[38;2;240;219;79m\27[0m " }, style = { fg = { Rgb = { 240, 219, 79 } } } }
xplr.config.node_types.extension["ts"] = { meta = { icon = "\27[38;2;49;120;198m󰛦\27[0m " }, style = { fg = { Rgb = { 49, 120, 198 } } } }
xplr.config.node_types.extension["lua"] = { meta = { icon = "\27[38;2;90;120;230m\27[0m " }, style = { fg = { Rgb = { 90, 120, 230 } } } }
xplr.config.node_types.extension["json"] = { meta = { icon = "\27[38;2;240;200;80m\27[0m " }, style = { fg = { Rgb = { 240, 200, 80 } } } }
xplr.config.node_types.extension["md"] = { meta = { icon = "\27[38;2;245;220;90m\27[0m " }, style = { fg = { Rgb = { 245, 220, 90 } } } }
xplr.config.node_types.extension["markdown"] = { meta = { icon = "\27[38;2;245;220;90m\27[0m " }, style = { fg = { Rgb = { 245, 220, 90 } } } }
xplr.config.node_types.extension["html"] = { meta = { icon = "\27[38;2;228;79;38m\27[0m " }, style = { fg = { Rgb = { 228, 79, 38 } } } }
xplr.config.node_types.extension["htm"] = { meta = { icon = "\27[38;2;228;79;38m\27[0m " }, style = { fg = { Rgb = { 228, 79, 38 } } } }
xplr.config.node_types.extension["css"] = { meta = { icon = "\27[38;2;66;133;244m\27[0m " }, style = { fg = { Rgb = { 66, 133, 244 } } } }
xplr.config.node_types.extension["sh"] = { meta = { icon = "\27[38;2;140;220;90m\27[0m " }, style = { fg = { Rgb = { 140, 220, 90 } } } }
xplr.config.node_types.extension["bash"] = { meta = { icon = "\27[38;2;140;220;90m\27[0m " }, style = { fg = { Rgb = { 140, 220, 90 } } } }
xplr.config.node_types.extension["zsh"] = { meta = { icon = "\27[38;2;140;220;90m\27[0m " }, style = { fg = { Rgb = { 140, 220, 90 } } } }
xplr.config.node_types.extension["yml"] = { meta = { icon = "\27[38;2;203;120;230m\27[0m " }, style = { fg = { Rgb = { 203, 120, 230 } } } }
xplr.config.node_types.extension["yaml"] = { meta = { icon = "\27[38;2;203;120;230m\27[0m " }, style = { fg = { Rgb = { 203, 120, 230 } } } }
xplr.config.node_types.extension["toml"] = { meta = { icon = "\27[38;2;210;160;120m\27[0m " }, style = { fg = { Rgb = { 210, 160, 120 } } } }
xplr.config.node_types.extension["ini"] = { meta = { icon = "\27[38;2;150;150;150m\27[0m " }, style = { fg = { Rgb = { 150, 150, 150 } } } }
xplr.config.node_types.extension["cfg"] = { meta = { icon = "\27[38;2;150;150;150m\27[0m " }, style = { fg = { Rgb = { 150, 150, 150 } } } }
xplr.config.node_types.extension["conf"] = { meta = { icon = "\27[38;2;150;150;150m\27[0m " }, style = { fg = { Rgb = { 150, 150, 150 } } } }
xplr.config.node_types.extension["lock"] = { meta = { icon = "\27[38;2;225;90;90m\27[0m " }, style = { fg = { Rgb = { 225, 90, 90 } } } }
xplr.config.node_types.extension["png"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["jpg"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["jpeg"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["gif"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["svg"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["webp"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["ico"] = { meta = { icon = "\27[38;2;190;130;245m\27[0m " }, style = { fg = { Rgb = { 190, 130, 245 } } } }
xplr.config.node_types.extension["txt"] = { meta = { icon = "\27[38;2;160;168;180m\27[0m " }, style = { fg = { Rgb = { 160, 168, 180 } } } }
xplr.config.node_types.extension["log"] = { meta = { icon = "\27[38;2;160;168;180m\27[0m " }, style = { fg = { Rgb = { 160, 168, 180 } } } }

xplr.config.node_types.special[".git"] = { meta = { icon = "\27[38;2;240;80;50m󰊢\27[0m " }, style = { fg = { Rgb = { 240, 80, 50 } } } }
xplr.config.node_types.special[".gitignore"] = { meta = { icon = "\27[38;2;130;130;130m󰊢\27[0m " }, style = { fg = { Rgb = { 130, 130, 130 } } } }
xplr.config.node_types.special[".gitattributes"] = { meta = { icon = "\27[38;2;130;130;130m󰊢\27[0m " }, style = { fg = { Rgb = { 130, 130, 130 } } } }
xplr.config.node_types.special[".gitmodules"] = { meta = { icon = "\27[38;2;130;130;130m󰊢\27[0m " }, style = { fg = { Rgb = { 130, 130, 130 } } } }
xplr.config.node_types.special["node_modules"] = { meta = { icon = "\27[38;2;92;98;110m\27[0m " }, style = { fg = { Rgb = { 92, 98, 110 } } } }
xplr.config.node_types.special["__pycache__"] = { meta = { icon = "\27[38;2;92;98;110m\27[0m " }, style = { fg = { Rgb = { 92, 98, 110 } } } }
xplr.config.node_types.special[".venv"] = { meta = { icon = "\27[38;2;92;98;110m\27[0m " }, style = { fg = { Rgb = { 92, 98, 110 } } } }
xplr.config.node_types.special["venv"] = { meta = { icon = "\27[38;2;92;98;110m\27[0m " }, style = { fg = { Rgb = { 92, 98, 110 } } } }
xplr.config.node_types.special[".DS_Store"] = { meta = { icon = "\27[38;2;92;98;110m\27[0m " }, style = { fg = { Rgb = { 92, 98, 110 } } } }

