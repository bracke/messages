with AUnit.Assertions;

with Messages.Program_Locale;

--  Messages.Program_Locale: which language a program's catalogue renders in,
--  from the POSIX variables and the host's own locale.
package body Messages.Runtime.Tests.Program_Locale is

   use AUnit.Assertions;

   package Choice renames Messages.Program_Locale;

   procedure Test_Language_Of
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Environment_Wins
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Native_When_Environment_Unset
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("program catalogue locale choice");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Language_Of'Access,
         "the language is cut from POSIX and BCP 47 spellings alike");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Environment_Wins'Access,
         "a set POSIX variable decides, in LC_ALL, LC_MESSAGES, LANG order");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Native_When_Environment_Unset'Access,
         "with no variable set the host's own locale decides");
   end Register_Tests;

   procedure Test_Language_Of
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Choice.Language_Of ("de_DE.UTF-8") = "de", "POSIX language_territory.codeset");
      Assert (Choice.Language_Of ("en-GB") = "en", "Windows' BCP 47 spelling");
      Assert (Choice.Language_Of ("en_GB") = "en", "macOS' underscore spelling");
      Assert (Choice.Language_Of ("sr@latin") = "sr", "a modifier");
      Assert (Choice.Language_Of ("fr") = "fr", "a bare language");
      Assert (Choice.Language_Of ("C") = "", "C names no language");
      Assert (Choice.Language_Of ("POSIX") = "", "POSIX names no language");
      Assert (Choice.Language_Of ("C.UTF-8") = "", "C.UTF-8 names no language");
      Assert (Choice.Language_Of ("") = "", "nothing names no language");
   end Test_Language_Of;

   procedure Test_Environment_Wins
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Choice.Choose ("da_DK.UTF-8", "de_DE", "fr_FR", "ja-JP") = "da", "LC_ALL first");
      Assert (Choice.Choose ("", "de_DE", "fr_FR", "ja-JP") = "de", "then LC_MESSAGES");
      Assert (Choice.Choose ("", "", "fr_FR", "ja-JP") = "fr", "then LANG");
      Assert (Choice.Choose ("C", "", "", "ja-JP") = "en",
              "an explicit C locale is English, not the host's language");
   end Test_Environment_Wins;

   procedure Test_Native_When_Environment_Unset
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Choice.Choose ("", "", "", "de-AT") = "de", "Windows' native locale");
      Assert (Choice.Choose ("", "", "", "ja_JP") = "ja", "macOS' native locale");
      Assert (Choice.Choose ("", "", "", "") = "en", "no answer anywhere is English");
   end Test_Native_When_Environment_Unset;

end Messages.Runtime.Tests.Program_Locale;
