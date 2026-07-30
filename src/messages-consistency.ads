with Ada.Strings.Unbounded;

--  Is a translation consistent with the message it translates?
--
--  Messages.Runtime.Validate_Catalog_File answers whether a catalog is
--  well-formed. This answers something a well-formed catalog can still get
--  wrong: a locale that has drifted from the default one it was translated
--  from.
--
--  None of it judges a translation -- that needs somebody who speaks the
--  language. It catches what does not: a message translated from a key that no
--  longer exists, an argument dropped so the filename never appears in the
--  text, an option name translated into a word the program will reject, and an
--  apostrophe that ICU reads as an escape and that swallows the argument after
--  it.
--
--  The tokens that must survive translation are the caller's to name. This
--  package has no opinion about which words are commands, options or product
--  names; it only knows that if the default locale says one and the translation
--  does not, a user who types what they were shown gets an error.
package Messages.Consistency is

   subtype Unbounded_String is Ada.Strings.Unbounded.Unbounded_String;

   type Finding_Kind is
     (Missing_Original,
      --  A translated key the default locale does not have. Nothing can ever
      --  ask for it: the key it was written for is gone or misspelled.

      Argument_Dropped,
      --  The original takes an argument the translation does not. The message
      --  renders without the value it was about -- a file that is missing,
      --  without the filename.

      Argument_Added,
      --  The translation takes an argument the original does not, which no
      --  caller will supply.

      Token_Dropped,
      --  A token the caller named -- an option, a command, a product name --
      --  is in the original and not in the translation.

      Escape_Hazard,
      --  An apostrophe that ICU reads as the start of a quoted literal, which
      --  swallows the argument that follows it.

      Identical_To_Original);
      --  Word for word the default locale's text. Untranslated, or a
      --  coincidence worth a glance.

   type Finding is record
      Kind   : Finding_Kind := Missing_Original;
      Locale : Unbounded_String;
      Key    : Unbounded_String;
      Detail : Unbounded_String;
   end record;

   Max_Findings : constant Positive := 512;

   type Finding_Array is array (1 .. Max_Findings) of Finding;

   --  Fixed storage, like the rest of this crate: a report that allocates is a
   --  report that can fail while explaining a failure. Overflow says the
   --  catalog had more to say than there was room for.
   type Report is record
      Items    : Finding_Array;
      Count    : Natural range 0 .. Max_Findings := 0;
      Overflow : Boolean := False;
   end record;

   type Token_Array is array (Positive range <>) of Unbounded_String;

   No_Tokens : constant Token_Array (1 .. 0) := [others => <>];

   --  Check a catalog's translations against its default locale.
   --
   --  @param Source_Name Logical name used in findings.
   --  @param Text Catalog text in the canonical line format.
   --  @param Verbatim Tokens that must survive translation where the default
   --                  locale uses them: option names, command names, product
   --                  names. Empty checks none.
   --  @param Into The findings, emptied first.
   procedure Check_Text
     (Source_Name : String;
      Text        : String;
      Verbatim    : Token_Array := No_Tokens;
      Into        : out Report);

   --  The same, over a file. A file that cannot be read is one finding saying
   --  so, rather than an exception.
   procedure Check_File
     (Path     : String;
      Verbatim : Token_Array := No_Tokens;
      Into     : out Report);

   --  One line a person can read, of the form
   --  "de.error.missing_value: the argument {value} is dropped".
   function Image (Item : Finding) return String;

end Messages.Consistency;
