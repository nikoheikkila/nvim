Feature: New note from template
  Pressing <leader>nt picks a template and creates a note in the vault Inbox, named by timestamp, in a new buffer.

  Background:
    Given a vault with "obsidian.templates.folder" set to a directory containing "Interview.md"
    And "Interview.md" contains "# {{title}}" and "Date: {{date}}"

  Scenario: Create a note from a template
    Given I am editing "work.md"
    When I press <leader>nt, pick "Interview" and press Enter at the title prompt
    Then a note named by the current time as YYYY-MM-DD-HHmmss exists in "000 - Inbox"
    And its heading is that timestamp and its date line shows today's date
    And the new note is open and focused in a new buffer
    And "work.md" is still loaded, unchanged

  Scenario: Typed title names the file
    When I press <leader>nt, pick "Interview" and type "Ada Lovelace" at the title prompt
    Then a note named "Ada Lovelace.md" exists in "000 - Inbox"
    And its heading is "Ada Lovelace"

  Scenario: Cancel the picker
    When I press <leader>nt and cancel the picker
    Then no file is created in "000 - Inbox"
    And my current buffer is unchanged

  Scenario Outline: Templates folder is not usable
    Given "obsidian.templates.folder" is <state>
    When I press <leader>nt
    Then I see the warning "Templates folder is not defined or does not exist"
    And no file is created

    Examples:
      | state                       |
      | unset                       |
      | a directory that is missing |

  Scenario: Templates folder is empty
    Given the templates folder contains no templates
    When I press <leader>nt
    Then the picker shows no templates
    And no file is created when I cancel it

  Scenario: Template with an unknown variable
    Given "Notes.md" contains "Candidate: {{candidate}}"
    When I press <leader>nt, pick "Notes" and enter "Ada" at the variable prompt
    Then the new note contains "Candidate: Ada"

  Scenario: Skipped variable prompt
    Given "Notes.md" contains "Candidate: {{candidate}}"
    When I press <leader>nt, pick "Notes" and skip the variable prompt
    Then the new note is still created

  Scenario: Only Markdown files are offered
    Given the templates folder also contains "image.png"
    When I press <leader>nt
    Then the picker lists "Interview" and not "image.png"

  Scenario: Custom notes folder
    Given "obsidian.templates.notesFolder" is "Meetings"
    When I press <leader>nt and pick "Interview"
    Then the new note is created in "Meetings"

  Scenario: Notes folder is missing
    Given the notes folder does not exist
    When I press <leader>nt and pick "Interview"
    Then the notes folder is created
    And the new note exists in it

  Scenario: Works from a buffer outside the vault
    Given I am editing a file outside the vault
    When I press <leader>nt and pick "Interview"
    Then the note is created in the vault Inbox and opens in a new buffer

  Scenario: Other note creation follows the same defaults
    When I run ":Obsidian new" and press Enter at any title prompt
    Then the note is created in "000 - Inbox" with a timestamp name

  Scenario: Daily notes are unchanged
    When I run ":Obsidian today"
    Then today's note opens in the "dailyNotes.folder" folder
