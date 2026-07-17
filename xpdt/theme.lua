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


-- Theme the base node types (directory / file / symlink) and the dimmed / special
-- groups from a per-theme palette chosen by the `theme` setting (~/.config/xpdt/
-- .gate-config, default monokai; applies on the next launch). This runs after the
-- definitions above and only rewrites their colour, keeping the icon glyphs. The
-- per-extension colours above stay semantic (a Python file is Python-yellow on any
-- theme). Neovim, bat previews and the fzf browsers are themed to match elsewhere.
local function xpdt_read_theme()
  local t = "monokai"
  local f = io.open(os.getenv("HOME") .. "/.config/xpdt/.gate-config", "r")
  if f then
    for line in f:lines() do
      local v = line:match("^theme=(%w+)")
      if v then
        t = v
      end
    end
    f:close()
  end
  return t
end

local XPDT_PALETTES = {
  monokai = { dir = { 96, 160, 255 }, file = { 150, 160, 175 }, link = { 120, 220, 232 }, dim = { 92, 98, 110 }, muted = { 130, 130, 130 }, red = { 240, 80, 50 } },
  gruvbox = { dir = { 131, 165, 152 }, file = { 235, 219, 178 }, link = { 142, 192, 124 }, dim = { 102, 92, 84 }, muted = { 146, 131, 116 }, red = { 251, 73, 52 } },
  nord = { dir = { 129, 161, 193 }, file = { 216, 222, 233 }, link = { 136, 192, 208 }, dim = { 76, 86, 106 }, muted = { 97, 110, 136 }, red = { 191, 97, 106 } },
  dracula = { dir = { 189, 147, 249 }, file = { 248, 248, 242 }, link = { 139, 233, 253 }, dim = { 68, 71, 90 }, muted = { 98, 114, 164 }, red = { 255, 85, 85 } },
  tokyonight = { dir = { 122, 162, 247 }, file = { 192, 202, 245 }, link = { 125, 207, 255 }, dim = { 65, 72, 104 }, muted = { 86, 95, 137 }, red = { 247, 118, 142 } },
}
local XP = XPDT_PALETTES[xpdt_read_theme()] or XPDT_PALETTES.monokai

local function xpdt_recolor(nt, c)
  if not (nt and nt.meta and nt.meta.icon) then
    return
  end
  nt.meta.icon = nt.meta.icon:gsub(
    "^\27%[38;2;%d+;%d+;%d+m",
    string.format("\27[38;2;%d;%d;%dm", c[1], c[2], c[3])
  )
  nt.style = nt.style or {}
  nt.style.fg = { Rgb = { c[1], c[2], c[3] } }
end

xpdt_recolor(xplr.config.node_types.directory, XP.dir)
xpdt_recolor(xplr.config.node_types.file, XP.file)
xpdt_recolor(xplr.config.node_types.symlink, XP.link)
xpdt_recolor(xplr.config.node_types.special[".git"], XP.red)
for _, k in ipairs({ ".gitignore", ".gitattributes", ".gitmodules" }) do
  xpdt_recolor(xplr.config.node_types.special[k], XP.muted)
end
for _, k in ipairs({ "node_modules", "__pycache__", ".venv", "venv", ".DS_Store" }) do
  xpdt_recolor(xplr.config.node_types.special[k], XP.dim)
end
