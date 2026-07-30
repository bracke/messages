with AUnit.Assertions;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Messages.Consistency;

package body Messages.Runtime.Tests.Consistency is

   use AUnit.Assertions;
   use type Messages.Consistency.Finding_Kind;

   LF : constant Character := ASCII.LF;

   --  A catalog with one thing wrong in it, so a test says which rule fired
   --  rather than that something did.
   function Catalog (Broken : String) return String is
     ("default_locale = en" & LF
      & "en.error.missing_value = ""missing value for {value}""" & LF
      & "en.cli.commands = ""commands: help, version, install""" & LF
      & "en.error.unknown = ""unknown command""" & LF
      & Broken & LF);

   function Has (Into : Messages.Consistency.Report;
                 Kind : Messages.Consistency.Finding_Kind) return Boolean is
   begin
      for Index in 1 .. Into.Count loop
         if Into.Items (Index).Kind = Kind then
            return True;
         end if;
      end loop;
      return False;
   end Has;

   procedure Test_A_Sound_Translation_Is_Quiet
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into : Messages.Consistency.Report;
   begin
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("de.error.missing_value = ""fehlender Wert für {value}"""),
         Into => Into);
      Assert (Into.Count = 0, "a translation that keeps its argument is quiet");
   end Test_A_Sound_Translation_Is_Quiet;

   procedure Test_A_Dropped_Argument_Is_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into : Messages.Consistency.Report;
   begin
      --  The message still reads; it just never says which value.
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("de.error.missing_value = ""ein Wert fehlt"""),
         Into => Into);
      Assert (Has (Into, Messages.Consistency.Argument_Dropped),
              "an argument the original takes and the translation does not");
   end Test_A_Dropped_Argument_Is_Found;

   procedure Test_An_Invented_Argument_Is_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into : Messages.Consistency.Report;
   begin
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("de.error.unknown = ""unbekannter Befehl {name}"""),
         Into => Into);
      Assert (Has (Into, Messages.Consistency.Argument_Added),
              "an argument no caller will supply");
   end Test_An_Invented_Argument_Is_Found;

   procedure Test_A_Key_With_No_Original_Is_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into : Messages.Consistency.Report;
   begin
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("de.error.no_such_key = ""etwas"""),
         Into => Into);
      Assert (Has (Into, Messages.Consistency.Missing_Original),
              "a translation of a key nothing can ask for");
   end Test_A_Key_With_No_Original_Is_Found;

   procedure Test_A_Translated_Command_Is_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into   : Messages.Consistency.Report;
      Tokens : constant Messages.Consistency.Token_Array :=
        [1 => To_Unbounded_String ("install")];
   begin
      --  "installieren" is the word; "install" is what the program accepts.
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("de.cli.commands = ""Befehle: help, version, installieren"""),
         Verbatim => Tokens,
         Into     => Into);
      Assert (Has (Into, Messages.Consistency.Token_Dropped),
              "a command name that was translated into something else");
   end Test_A_Translated_Command_Is_Found;

   procedure Test_An_Escaping_Apostrophe_Is_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into : Messages.Consistency.Report;
   begin
      --  ICU reads the apostrophe as opening a literal, and the argument after
      --  it never renders.
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("fr.error.missing_value = ""valeur manquante d'{value}"""),
         Into => Into);
      Assert (Has (Into, Messages.Consistency.Escape_Hazard),
              "an apostrophe that swallows the argument after it");
   end Test_An_Escaping_Apostrophe_Is_Found;

   procedure Test_An_Untranslated_Line_Is_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Into : Messages.Consistency.Report;
   begin
      --  Two words can coincide between languages; four rarely do, which is
      --  where the rule draws its line.
      Messages.Consistency.Check_Text
        ("test",
         Catalog ("de.error.missing_value = ""missing value for {value}"""),
         Into => Into);
      Assert (Has (Into, Messages.Consistency.Identical_To_Original),
              "text that is word for word the original");
   end Test_An_Untranslated_Line_Is_Found;

   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String
   is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Messages.Consistency");
   end Name;

   overriding procedure Register_Tests
     (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_A_Sound_Translation_Is_Quiet'Access,
         "a sound translation is quiet");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_A_Dropped_Argument_Is_Found'Access,
         "a dropped argument is found");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_An_Invented_Argument_Is_Found'Access,
         "an invented argument is found");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_A_Key_With_No_Original_Is_Found'Access,
         "a key with no original is found");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_A_Translated_Command_Is_Found'Access,
         "a translated command name is found");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_An_Escaping_Apostrophe_Is_Found'Access,
         "an escaping apostrophe is found");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_An_Untranslated_Line_Is_Found'Access,
         "an untranslated line is found");
   end Register_Tests;

end Messages.Runtime.Tests.Consistency;
