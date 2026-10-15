-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2026 Dr. Johannes Brügmann
--
-- report.lua -- the pandoc filter for the reports of elvboot: colours and
-- sizes for the classes the Markdown carries (pass, fail, skip on spans;
-- every code span is a value -- a digest, a leaf, a file -- set in a
-- smaller monospace face that may break anywhere, so no hash runs off the
-- page). The Markdown stays plain and signable; this filter only renders.
--
--   pandoc report.md --lua-filter report.lua -H report.tex -o report.pdf
--   pandoc report.md --lua-filter report.lua -c report.css -s -o report.html

local function latex_escape(s)
  return (s:gsub('[\\{}%$&#_%%~^]', function(c)
    if c == '\\' then return '\\textbackslash{}' end
    if c == '~' then return '\\textasciitilde{}' end
    if c == '^' then return '\\textasciicircum{}' end
    return '\\' .. c
  end))
end

local colour = { pass = 'ReportPass', fail = 'ReportFail', skip = 'ReportSkip' }

function Span(el)
  for _, c in ipairs(el.classes) do
    if colour[c] then
      if FORMAT:match('latex') then
        local out = pandoc.List({ pandoc.RawInline('latex', '\\textcolor{' .. colour[c] .. '}{\\textbf{') })
        out:extend(el.content)
        out:insert(pandoc.RawInline('latex', '}}'))
        return out
      end
      return el
    end
  end
  return nil
end

function Code(el)
  if FORMAT:match('latex') then
    local words = {}
    for w in el.text:gmatch('%S+') do
      if #w > 24 then
        words[#words + 1] = '\\reportvalue{' .. latex_escape(w) .. '}'
      else
        words[#words + 1] = '\\reportword{' .. latex_escape(w) .. '}'
      end
    end
    if #words == 0 then words[1] = '\\reportvalue{}' end
    return pandoc.RawInline('latex', table.concat(words, ' '))
  end
  el.classes:insert('value')
  return el
end
