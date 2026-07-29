-- Run with: task test:unit

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.title_case")

-- Greek small beta and an em dash, spelled as bytes so this file stays ASCII.
local BETA = "\206\178"
local EM_DASH = "\226\128\148"

-- The worked examples from https://titlecapitalize.com/ama-title-case-rules/,
-- as wrong -> right pairs.
local REFERENCE = {
  { "Journal Of Clinical Epidemiology", "Journal of Clinical Epidemiology" },
  { "Randomized Trials In Cardiovascular Medicine", "Randomized Trials in Cardiovascular Medicine" },
  { "Meta-analysis methods For Evidence Synthesis", "Meta-Analysis Methods for Evidence Synthesis" },
  { "Public health ethics in emergency response", "Public Health Ethics in Emergency Response" },
  { "Principles of molecular genetics", "Principles of Molecular Genetics" },
  { "Diabetes Care And Education Essentials", "Diabetes Care and Education Essentials" },
  { "Imaging Of The Chest in Acute infection", "Imaging of the Chest in Acute Infection" },
  { "Pharmacology of " .. BETA .. "-blocker therapy", "Pharmacology of " .. BETA .. "-Blocker Therapy" },
  { "Oncology: immunotherapy with anti-PD-1 agents", "Oncology: Immunotherapy With Anti-PD-1 Agents" },
  { "Pediatrics In Primary Care Practice", "Pediatrics in Primary Care Practice" },
}

describe("AMA reference examples", function()
  for _, pair in ipairs(REFERENCE) do
    local wrong, right = pair[1], pair[2]
    it(wrong, function()
      assert.are.equal(right, M.transform_line(wrong))
    end)
  end
end)

describe("lowercase set", function()
  it("lowercases a minor word mid-title", function()
    assert.are.equal("Studies of Medicine", M.transform_line("studies of medicine"))
  end)

  it("capitalizes a minor word that opens the title", function()
    assert.are.equal("The Chest in Infection", M.transform_line("the chest in infection"))
  end)

  it("capitalizes a minor word that closes the title", function()
    assert.are.equal("Diseases We Care For", M.transform_line("diseases we care for"))
  end)

  it("capitalizes the first word of a subtitle", function()
    assert.are.equal("Review: Of Mice and Men", M.transform_line("review: of mice and men"))
  end)

  it("capitalizes prepositions of four or more letters", function()
    assert.are.equal(
      "Trials With Insulin Between Doses Through Winter",
      M.transform_line("trials with insulin between doses through winter")
    )
  end)

  it("capitalizes subordinating conjunctions", function()
    assert.are.equal("Care Because Although While Trials", M.transform_line("care because although while trials"))
  end)

  it("capitalizes two-letter verbs but not two-letter prepositions", function()
    assert.are.equal("Is It Be to at by per Ready", M.transform_line("is it be to at by per ready"))
  end)
end)

describe("abbreviation preservation", function()
  it("keeps DNA", function()
    assert.are.equal("Repair of DNA Damage", M.transform_line("repair of DNA damage"))
  end)

  it("keeps a lowercase-initial abbreviation", function()
    assert.are.equal("Decline in eGFR Values", M.transform_line("decline in eGFR values"))
  end)

  it("keeps a mixed-case abbreviation", function()
    assert.are.equal("Tracking HbA1c and mRNA", M.transform_line("tracking HbA1c and mRNA"))
  end)

  it("keeps a hyphenated abbreviation", function()
    assert.are.equal("Spread of SARS-CoV-2", M.transform_line("spread of SARS-CoV-2"))
  end)

  it("capitalizes the plain element of a mixed hyphenated word", function()
    assert.are.equal("Anti-PD-1 Agents", M.transform_line("anti-PD-1 agents"))
  end)

  it("leaves an all-caps line untouched", function()
    assert.are.equal("IMAGING OF THE CHEST", M.transform_line("IMAGING OF THE CHEST"))
  end)

  it("cannot recover a lowercase abbreviation", function()
    assert.are.equal("The Study of Dna", M.transform_line("the study of dna"))
  end)
end)

describe("hyphenated compounds", function()
  it("capitalizes both elements", function()
    assert.are.equal("Meta-Analysis Methods", M.transform_line("meta-analysis methods"))
  end)

  it("leaves a Greek first element alone", function()
    assert.are.equal(BETA .. "-Blocker Therapy", M.transform_line(BETA .. "-blocker therapy"))
  end)

  it("lowercases minor elements after the first", function()
    assert.are.equal("State-of-the-Art Care", M.transform_line("state-of-the-art care"))
  end)

  it("capitalizes the first element even when it is a minor word", function()
    assert.are.equal("Trials of For-Profit Clinics", M.transform_line("trials of for-profit clinics"))
  end)

  -- The last-word rule reaches a compound's first element, not its last, so a
  -- minor word trailing a hyphen stays lowercase even at the end of the title.
  it("leaves a minor final element lowercase", function()
    assert.are.equal("Diseases We Care-for", M.transform_line("diseases we care-for"))
  end)

  it("keeps a number element", function()
    assert.are.equal("Covid-19 Cases", M.transform_line("covid-19 cases"))
  end)

  it("keeps an all-caps number element", function()
    assert.are.equal("COVID-19 Cases", M.transform_line("COVID-19 cases"))
  end)

  it("survives a trailing hyphen", function()
    assert.are.equal("Post- and Pre-Operative", M.transform_line("post- and pre-operative"))
  end)

  it("survives a leading hyphen", function()
    assert.are.equal("-Blocker Use", M.transform_line("-blocker use"))
  end)

  it("survives a double hyphen", function()
    assert.are.equal("Double--Hyphen of X", M.transform_line("double--hyphen of x"))
  end)
end)

describe("whitespace preservation", function()
  it("keeps leading indentation", function()
    assert.are.equal("  Indented Title of Things", M.transform_line("  indented title of things"))
  end)

  it("keeps tabs between words", function()
    assert.are.equal("A\tTabbed\tTitle of X", M.transform_line("a\ttabbed\ttitle of x"))
  end)

  it("keeps runs of spaces", function()
    assert.are.equal("Spaced   Out  Title of X", M.transform_line("spaced   out  title of x"))
  end)

  it("keeps trailing whitespace", function()
    assert.are.equal("Title of X  ", M.transform_line("title of x  "))
  end)

  it("keeps a trailing carriage return", function()
    assert.are.equal("Title of X\r", M.transform_line("title of x\r"))
  end)
end)

describe("punctuation", function()
  it("capitalizes a minor word closing the title despite a full stop", function()
    assert.are.equal("Diseases We Care For.", M.transform_line("diseases we care for."))
  end)

  it("keeps parentheses", function()
    assert.are.equal("(Parenthesised) Title of X", M.transform_line("(parenthesised) title of x"))
  end)

  it("keeps surrounding quotes", function()
    assert.are.equal("'Quoted' Words of Note", M.transform_line("'quoted' words of note"))
  end)

  it("keeps an internal apostrophe", function()
    assert.are.equal("Alzheimer's Disease of the Brain", M.transform_line("alzheimer's disease of the brain"))
  end)

  it("keeps a contraction", function()
    assert.are.equal("Don't Stop the Music", M.transform_line("don't stop the music"))
  end)

  it("handles a colon at the end of a line", function()
    assert.are.equal("Trailing Colon of X:", M.transform_line("trailing colon of x:"))
  end)
end)

describe("degenerate input", function()
  it("returns an empty line unchanged", function()
    assert.are.equal("", M.transform_line(""))
  end)

  it("returns a whitespace-only line unchanged", function()
    assert.are.equal("   ", M.transform_line("   "))
  end)

  it("capitalizes a single word", function()
    assert.are.equal("Genetics", M.transform_line("genetics"))
  end)

  it("capitalizes a lone minor word, being both first and last", function()
    assert.are.equal("Of", M.transform_line("of"))
  end)

  it("capitalizes a single letter", function()
    assert.are.equal("A", M.transform_line("a"))
  end)

  it("leaves a number-only token alone", function()
    assert.are.equal("Type 2 Diabetes", M.transform_line("type 2 diabetes"))
  end)

  it("skips letter-free tokens when locating the first word", function()
    assert.are.equal(EM_DASH .. " Dash of X", M.transform_line(EM_DASH .. " dash of x"))
  end)

  it("treats a minor word between numbers as both first and last", function()
    assert.are.equal("19 And 42", M.transform_line("19 and 42"))
  end)

  it("leaves a line with no letters alone", function()
    assert.are.equal("19 42 -- 7", M.transform_line("19 42 -- 7"))
  end)
end)

describe("idempotence", function()
  for _, pair in ipairs(REFERENCE) do
    local right = pair[2]
    it(right, function()
      assert.are.equal(right, M.transform_line(right))
    end)
  end
end)

describe("transform", function()
  it("cases a single line like transform_line", function()
    assert.are.equal("Principles of Molecular Genetics", M.transform("principles of molecular genetics"))
  end)

  it("treats each line as its own title", function()
    assert.are.equal(
      "Journal of Epidemiology\nTrials in Medicine",
      M.transform("journal of epidemiology\ntrials in medicine")
    )
  end)

  it("preserves blank lines and the line count", function()
    assert.are.equal(
      "Journal of Epidemiology\n\n  Trials in Medicine",
      M.transform("journal of epidemiology\n\n  trials in medicine")
    )
  end)

  it("preserves a trailing newline", function()
    assert.are.equal("Care of X\n", M.transform("care of x\n"))
  end)

  it("returns empty text unchanged", function()
    assert.are.equal("", M.transform(""))
  end)
end)
