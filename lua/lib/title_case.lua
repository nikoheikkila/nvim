local M = {}

-- Words AMA keeps lowercase when they fall inside a title, exactly as enumerated
-- by https://titlecapitalize.com/ama-title-case-rules/. This table is the one
-- place to extend: prepositions of four or more letters (With, Between,
-- Through) are capitalized, and unlisted short words are deliberately absent —
-- "up", "out" and "off" read as prepositions but usually appear as adverbs or
-- verb particles, which AMA capitalizes.
local MINOR_WORDS = {
  -- articles
  ["a"] = true,
  ["an"] = true,
  ["the"] = true,
  -- coordinating conjunctions
  ["and"] = true,
  ["but"] = true,
  ["or"] = true,
  ["nor"] = true,
  ["for"] = true,
  ["so"] = true,
  ["yet"] = true,
  -- prepositions of three or fewer letters
  ["of"] = true,
  ["in"] = true,
  ["to"] = true,
  ["on"] = true,
  ["at"] = true,
  ["by"] = true,
  ["per"] = true,
}

-- Punctuation peeled off the ends of a token before its case is decided, so
-- that (parenthesised, "quoted and care for. keep their decoration while the
-- word inside is still recognised. Written as an explicit ASCII class rather
-- than %p because %p is locale-dependent for bytes above 0x7f, and this module
-- runs both under the unit suite's Lua and inside Neovim's LuaJIT. A hyphen is
-- absent on purpose: it is structural, and split_hyphens handles it.
local EDGE_PUNCTUATION = "[%(%)%[%]{}<>\"',;:%.!%?%*_`]"

-- Split a token into the punctuation before it, the word itself, and the
-- punctuation after it. Interior punctuation is untouched, so "Alzheimer's"
-- comes back whole.
local function split_affixes(token)
  local first, last = 1, #token
  while first <= last and token:sub(first, first):match(EDGE_PUNCTUATION) do
    first = first + 1
  end
  while last >= first and token:sub(last, last):match(EDGE_PUNCTUATION) do
    last = last - 1
  end
  return token:sub(1, first - 1), token:sub(first, last), token:sub(last + 1)
end

-- Uppercase the first character of word. Byte-wise upper() leaves bytes above
-- 0x7f alone, so a word opening with a multibyte character passes through
-- unchanged — which is what AMA wants for β-blocker.
local function capitalize(word)
  if word == "" then
    return word
  end
  return word:sub(1, 1):upper() .. word:sub(2)
end

-- Split str on a literal delimiter, keeping empty segments so that a leading or
-- trailing delimiter survives the round trip: "post-" stays "post-", and a
-- trailing newline stays a trailing newline.
local function split(str, delimiter)
  local segments, from = {}, 1
  while true do
    local at = str:find(delimiter, from, true)
    if not at then
      segments[#segments + 1] = str:sub(from)
      return segments
    end
    segments[#segments + 1] = str:sub(from, at - 1)
    from = at + 1
  end
end

-- True when a segment carries its own capitalisation and must be left alone:
-- an ASCII capital anywhere past the first character marks an abbreviation
-- (DNA, CoV, PD, HbA1c, eGFR) rather than an ordinary word.
local function is_abbreviation(segment)
  return segment:sub(2):find("[A-Z]") ~= nil
end

-- Case one word. force_capital is set for the words AMA capitalizes regardless
-- of their part of speech: the first word, the last word, and the first word of
-- a subtitle. Hyphenated compounds capitalize their first element
-- unconditionally, and their later elements unless those are minor words.
local function case_word(word, force_capital)
  local segments = split(word, "-")
  local hyphenated = #segments > 1

  for index, segment in ipairs(segments) do
    if not is_abbreviation(segment) then
      local lowered = segment:lower()
      -- A compound's first element is capitalized whatever it is, as is any word
      -- AMA forces outright; every other segment defers to the minor-word list.
      local forced = index == 1 and (force_capital or hyphenated)
      segments[index] = (not forced and MINOR_WORDS[lowered]) and lowered or capitalize(lowered)
    end
  end

  return table.concat(segments, "-")
end

-- Title-case a single line under the AMA rules. Every whitespace byte is
-- preserved — indentation, tabs, runs of spaces, trailing whitespace and a
-- trailing carriage return all survive, because only the %S+ runs are rewritten.
function M.transform_line(line)
  -- Take the line apart once, recording which tokens carry letters and which of
  -- those come first and last. Letter-free tokens (a lone quote, a number, an em
  -- dash) are passed over here so they cannot take the first-word slot away from
  -- the word that follows them.
  local tokens = {}
  local first, last
  for token in line:gmatch("%S+") do
    local prefix, word, suffix = split_affixes(token)
    local lettered = word:find("[A-Za-z]") ~= nil
    tokens[#tokens + 1] = { text = token, prefix = prefix, word = word, suffix = suffix, lettered = lettered }
    if lettered then
      first = first or #tokens
      last = #tokens
    end
  end

  -- Rewriting only the %S+ runs is what preserves every whitespace byte, and
  -- gsub walks them in the order they were recorded above.
  local index = 0
  return (
    line:gsub("%S+", function(text)
      index = index + 1
      local token = tokens[index]
      if not token.lettered then
        return text
      end
      local previous = tokens[index - 1]
      local after_colon = previous ~= nil and previous.text:sub(-1) == ":"
      local force_capital = index == first or index == last or after_colon
      return token.prefix .. case_word(token.word, force_capital) .. token.suffix
    end)
  )
end

-- Title-case text, treating each line as a title of its own so that the
-- first-word and last-word rules apply per line. Line endings are preserved.
function M.transform(text)
  local lines = split(text, "\n")
  for index, line in ipairs(lines) do
    lines[index] = M.transform_line(line)
  end
  return table.concat(lines, "\n")
end

return M
