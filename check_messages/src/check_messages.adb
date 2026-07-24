with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Files;
with Project_Tools.JSON;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Text;
with Project_Tools.Tree_Checks;

--  Release gate for the messages crate: it builds and runs the AUnit suite and
--  the ICU/CLDR message-rendering conformance harness, builds the worked
--  examples and checks their output against examples/EXPECTED_OUTPUT.md, runs
--  the render-benchmark smoke check, and verifies the crate's file inventory
--  and AI metadata. The message-formatting layer was split out of the i18n
--  platform crate; the platform's own gate lives in ../i18n/check_i18n.
procedure Check_Messages is
   use Ada.Text_IO;
   use GNAT.OS_Lib;

   Alr_Build_Args : constant Argument_List :=
     [1 => new String'("build")];
   Exec_Tests_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("./bin/tests")];
   Build_Tests_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("tests.gpr")];
   Build_Examples_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("examples.gpr"),
      6 => new String'("-j1")];
   No_Args : constant Argument_List (1 .. 0) := [others => null];
   Build_Benchmarks_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("benchmarks.gpr"),
      6 => new String'("-j1")];
   Build_Conformance_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("conformance.gpr")];
   Run_Benchmarks_Args : constant Argument_List :=
     [1 => new String'("--smoke")];

   function Root_Directory return String is
      Root : constant String :=
        Project_Tools.Files.Find_Root_Upward (".", "messages.gpr");
   begin
      if Root'Length = 0 then
         Put_Line (Standard_Error, "messages root not found");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;

      return Root;
   end Root_Directory;

   Root   : constant String := Root_Directory;
   Checks : constant Project_Tools.Release_Checks.Checker :=
     Project_Tools.Release_Checks.Create (Root);
   Errors : Natural := 0;

   procedure Error (Message : String) is
   begin
      Errors := Errors + 1;
      Put_Line (Standard_Error, "error: " & Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Error;

   function Alr_Path return String is
   begin
      return Project_Tools.Processes.Locate_Command ("alr");
   end Alr_Path;

   procedure Run_Check
     (Label   : String;
      Dir     : String;
      Program : String;
      Args    : Argument_List)
   is
   begin
      Project_Tools.Release_Checks.Run
        (Label   => Label,
         Dir     => Dir,
         Program => Program,
         Args    => Args,
         Quiet   => False);
   exception
      when Program_Error =>
         Error (Label & " failed");
   end Run_Check;

   procedure Check_Example_Output is
      use Ada.Strings.Unbounded;

      LF   : constant String := [1 => ASCII.LF];
      Euro : constant String :=
        Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#);
      Yen : constant String :=
        Character'Val (16#C2#) & Character'Val (16#A5#);
      Per_Mille : constant String :=
        Character'Val (16#E2#) & Character'Val (16#80#)
        & Character'Val (16#B0#);
      Arabic_Number : constant String :=
        Character'Val (16#D9#) & Character'Val (16#A1#)
        & Character'Val (16#D9#) & Character'Val (16#AC#)
        & Character'Val (16#D9#) & Character'Val (16#A2#)
        & Character'Val (16#D9#) & Character'Val (16#A3#)
        & Character'Val (16#D9#) & Character'Val (16#A4#)
        & Character'Val (16#D9#) & Character'Val (16#AC#)
        & Character'Val (16#D9#) & Character'Val (16#A5#)
        & Character'Val (16#D9#) & Character'Val (16#A6#)
        & Character'Val (16#D9#) & Character'Val (16#A7#)
        & Character'Val (16#D9#) & Character'Val (16#AB#)
        & Character'Val (16#D9#) & Character'Val (16#A8#)
        & Character'Val (16#D9#) & Character'Val (16#A9#);
      Reiwa_Date : constant String :=
        Character'Val (16#E4#) & Character'Val (16#BB#)
        & Character'Val (16#A4#) & Character'Val (16#E5#)
        & Character'Val (16#92#) & Character'Val (16#8C#)
        & " 6" & Character'Val (16#E5#) & Character'Val (16#B9#)
        & Character'Val (16#B4#) & "2" & Character'Val (16#E6#)
        & Character'Val (16#9C#) & Character'Val (16#88#)
        & "29" & Character'Val (16#E6#) & Character'Val (16#97#)
        & Character'Val (16#A5#);
      Buddhist_Date : constant String :=
        Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#92#) & Character'Val (16#E0#)
        & Character'Val (16#B9#) & Character'Val (16#99#)
        & Character'Val (16#20#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#81#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#B8#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#A1#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#A0#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#B2#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#9E#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#B1#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#99#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#98#)
        & Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#8C#) & Character'Val (16#20#)
        & Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#92#) & Character'Val (16#E0#)
        & Character'Val (16#B9#) & Character'Val (16#95#)
        & Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#96#) & Character'Val (16#E0#)
        & Character'Val (16#B9#) & Character'Val (16#97#);

      procedure Expect_Example
        (Name          : String;
         Expected      : String;
         Prefix_Only   : Boolean := False)
      is
         Output : Project_Tools.Processes.Unbounded_String;
      begin
         if not Project_Tools.Files.File_Contains
           (Root & "/examples/EXPECTED_OUTPUT.md",
            "./examples/bin/" & Name)
         then
            Error ("example command is missing from EXPECTED_OUTPUT.md: " & Name);
         end if;
         if not Project_Tools.Files.File_Contains
           (Root & "/examples/EXPECTED_OUTPUT.md", Expected)
         then
            Error ("example expected output is missing from EXPECTED_OUTPUT.md: " & Name);
         end if;

         Project_Tools.Processes.Run
           (Label   => "run messages example " & Name,
            Dir     => Root,
            Program => Root & "/examples/bin/" & Name,
            Args    => No_Args,
            Output  => Output,
            Quiet   => True);

         declare
            Text : constant String := To_String (Output);
         begin
            if Prefix_Only then
               if Text'Length < Expected'Length
                 or else Text (Text'First .. Text'First + Expected'Length - 1)
                         /= Expected
               then
                  Error ("example output prefix drifted for " & Name);
               end if;
            elsif Text /= Expected then
               Error ("example output drifted for " & Name);
            end if;
         end;
      exception
         when Program_Error =>
            Error ("example failed: " & Name);
      end Expect_Example;
   begin
      Expect_Example
        ("hello_world",
         "hello world: Hello, Ada!" & LF);
      Expect_Example
        ("basic_render",
         "basic: Hello, Ada!" & LF);
      Expect_Example
        ("public_api_example",
         "public API render: Servus, Ada!" & LF);
      Expect_Example
        ("public_api_sealed",
         "public API sealed smoke: SUCCESS" & LF);
      Expect_Example
        ("plural_render",
         "plural one: One item" & LF
         & "plural other: 5 items" & LF);
      Expect_Example
        ("select_render",
         "select male: Tomcat" & LF
         & "select fallback branch: Unknown pet" & LF);
      Expect_Example
        ("selectordinal_render",
         "ordinal one: 1st place" & LF
         & "ordinal other: 4th place" & LF
         & "ordinal many: 8o posto speciale" & LF);
      Expect_Example
        ("nested_message_render",
         "nested select/plural: Grace uploaded 2 files" & LF);
      Expect_Example
        ("number_formatting",
         "number en: Number: 12,345.67" & LF
         & "number de: Zahl: 12.345,67" & LF
         & "number percent: Percent: 13%" & LF
         & "number permille: Permille: 125" & Per_Mille & LF
         & "number compact: Compact: 12.3K" & LF
         & "number scientific: Scientific: 1.23E+4" & LF
         & "number engineering: Engineering: 12.35E+3" & LF
         & "number spellout: Spellout: forty-two" & LF
         & "number trailing: Trailing stripped: 42" & LF
         & "number accounting: Accounting number: (12,345)" & LF
         & "number scale: Scaled: 12,345,670.00" & LF
         & "number arabic digits: Arabic digits: " & Arabic_Number & LF
         & "number indian grouping: Indian grouping: 12,34,567.89" & LF);
      Expect_Example
        ("currency_formatting",
         "currency en: Total: $1,234.50" & LF
         & "currency de: Summe: 1.234,50 " & Euro & LF
         & "currency name: Name: 1,234.50 US dollars" & LF
         & "currency narrow: Narrow: $1,234.50" & LF
         & "currency iso: ISO: USD 1,234.50" & LF
         & "currency cash: Cash: CHF 1.05" & LF
         & "currency accounting: Accounting: ($1,234.50)" & LF
         & "currency yen: Yen: " & Yen & "1,234" & LF);
      Expect_Example
        ("date_formatting",
         "date en: Date: February 29, 2024" & LF
         & "date de: Datum: Donnerstag, 29. Februar 2024" & LF
         & "date skeleton: Date skeleton: Feb 29, 2024" & LF
         & "date numeric skeleton: Numeric skeleton: 2024 02 29" & LF
         & "date japanese calendar: Japanese calendar: " & Reiwa_Date & LF
         & "date buddhist calendar: Buddhist calendar: "
         & Buddhist_Date & LF
         & "date locale week: Locale week fields: 2016/1/1/2016" & LF
         & "date persian calendar: Persian calendar: AP 1403 01 01" & LF);
      Expect_Example
        ("time_formatting",
         "time short: Time: 09:05" & LF
         & "time long: Time with seconds: 09:05:07" & LF
         & "time skeleton: Time skeleton: 09:05:07 AM" & LF
         & "time fraction: Fractional time: 09:05:07.123" & LF
         & "time zone: Zoned time: 09:05 EST" & LF
         & "time zone widths: Zone widths: "
         & "GMT-04:00|-04:00|-04:00|America/New_York" & LF
         & "time utc widths: UTC widths: Z|+00:00|UTC" & LF
         & "time datetime long: Long datetime: February 29, 2024 21:30:00"
         & LF
         & "time datetime full: Full datetime: Thursday, February 29, 2024 "
         & "21:30:00" & LF);
      Expect_Example
        ("domain_formatting",
         "domain duration: Duration: 1:01:01" & LF
         & "domain bytes: Size: 2 TiB" & LF
         & "domain unit: Distance: 1.5 kilometers" & LF
         & "domain rate: Rate: 1.5 kilometers per hour" & LF
         & "domain short rate: Short rate: 1.5 km/h" & LF
         & "domain relative: When: 3 days ago" & LF
         & "domain relative de: Wann: vor 3 Tagen" & LF
         & "domain list: List: red, green, and blue" & LF
         & "domain list de: Liste: red, green und blue" & LF);
      Expect_Example
        ("locale_fallback",
         "exact de-AT: Servus, Ada!" & LF
         & "parent de: 3 Artikel" & LF
         & "default en: Default fallback text for Ada." & LF);
      Expect_Example
        ("fallback_chain",
         "fallback de-AT exact: Servus, Ada!" & LF
         & "fallback de parent: 3 Artikel" & LF
         & "fallback default en: Default fallback text for Ada." & LF);
      Expect_Example
        ("default_locale_key",
         "unqualified catalog key uses default locale: "
         & "Unqualified default-locale text for Ada." & LF);
      Expect_Example
        ("equals_in_value",
         "equals in catalog value: "
         & "A value may contain = after the first separator." & LF);
      Expect_Example
        ("empty_message",
         "empty message status: SUCCESS" & LF
         & "empty message length: 0" & LF);
      Expect_Example
        ("missing_key",
         "missing key: MISSING_KEY" & LF);
      Expect_Example
        ("missing_argument",
         "missing argument: MISSING_ARGUMENT" & LF);
      Expect_Example
        ("invalid_argument",
         "invalid numeric argument: INVALID_ARGUMENT" & LF);
      Expect_Example
        ("invalid_catalog",
         "duplicate catalog valid: FALSE" & LF
         & "render after invalid catalog: EXECUTION_ERROR" & LF
         & "syntax catalog valid: FALSE" & LF);
      Expect_Example
        ("invalid_catalog_fields",
         "empty locale valid: FALSE" & LF
         & "empty key valid: FALSE" & LF
         & "empty default locale valid: FALSE" & LF);
      Expect_Example
        ("status_handling",
         "success status: success => Hello, Ada!" & LF
         & "missing argument status: required render argument was not supplied"
         & LF
         & "missing key status: message key not found after locale fallback"
         & LF);
      Expect_Example
        ("diagnostics_non_interference",
         "trace callback cannot affect render: Hello, Ada!" & LF
         & "diagnostic count: 0" & LF);
      Expect_Example
        ("diagnostics_inspection",
         "render status: MISSING_ARGUMENT" & LF
         & "has missing-variable diagnostic: TRUE" & LF
         & "diagnostic count: 1" & LF
         & "diagnostic 1: MISSING_VARIABLE key=name message=",
         Prefix_Only => True);
      Expect_Example
        ("reuse_runtime",
         "first render: Hello, Ada!" & LF
         & "second render: 7 Artikel" & LF);
      Expect_Example
        ("argument_lifecycle",
         "has name after set: TRUE" & LF
         & "name value: Ada" & LF
         & "has name after clear: FALSE" & LF);
   end Check_Example_Output;

   procedure Require_JSON_Field
     (Relative_Path : String;
      Field         : String;
      Expected      : String;
      Message       : String)
   is
      Text : constant String :=
        Ada.Strings.Unbounded.To_String
          (Project_Tools.Text.Read_Text_File (Root & "/" & Relative_Path));
      Value : constant String := Project_Tools.JSON.Field_Value (Text, Field);
   begin
      if Value /= Expected then
         Error (Message);
      end if;
   exception
      when others =>
         Error (Message);
   end Require_JSON_Field;

   procedure Check_AI_JSON_Metadata is
   begin
      Require_JSON_Field
        ("ai/API_MANIFEST.json",
         "language",
         "Ada 2022",
         "AI API manifest must be parseable JSON with the expected language");
      Require_JSON_Field
        ("ai/EXAMPLE_CATALOG.json",
         "example_project",
         "examples/examples.gpr",
         "AI example catalog must be parseable JSON with the example project");
      Require_JSON_Field
        ("ai/EXAMPLE_CATALOG.json",
         "primary_catalog",
         "examples/catalogs/messages.catalog",
         "AI example catalog must be parseable JSON with the primary catalog");
   end Check_AI_JSON_Metadata;

   procedure Run_Release_Builds is
   begin
      Run_Check ("build messages library", Root, Alr_Path, Alr_Build_Args);
      Run_Check ("build messages tests", Root & "/tests", Alr_Path, Build_Tests_Args);
      Run_Check ("run messages tests", Root & "/tests", Alr_Path, Exec_Tests_Args);
      Run_Check
        ("build messages examples", Root & "/examples", Alr_Path, Build_Examples_Args);
      Check_Example_Output;
      Run_Check
        ("build messages benchmarks", Root & "/benchmarks", Alr_Path,
         Build_Benchmarks_Args);
      Run_Check
        ("build messages ICU/CLDR conformance harness",
         Root & "/conformance",
         Alr_Path,
         Build_Conformance_Args);
      Run_Check
        ("run messages ICU/CLDR conformance harness",
         Root,
         Root & "/conformance/bin/check_conformance",
         No_Args);
      Run_Check
        ("run messages benchmark smoke",
         Root,
         Root & "/benchmarks/bin/render_benchmarks",
         Run_Benchmarks_Args);
   end Run_Release_Builds;

   procedure Check_Generated_Artifacts is
      Hygiene_Errors : Natural := 0;
   begin
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/tests/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/examples");
      Errors := Errors + Hygiene_Errors;
   end Check_Generated_Artifacts;

begin
   Project_Tools.Processes.Require_Command
     ("alr", "alr executable not found on PATH");

   if Project_Tools.Processes.Has_Argument ("--examples-only") then
      Check_Example_Output;
      if Errors = 0 then
         Put_Line ("messages example output checks passed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
      else
         Put_Line
           (Standard_Error,
            "messages example output checks failed:"
            & Natural'Image (Errors) & " error(s)");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      return;
   end if;

   --  File inventory: the message crate's structural surface.
   Project_Tools.Release_Checks.Require_File (Checks, "README.md");
   Project_Tools.Release_Checks.Require_File (Checks, "messages.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "alire.toml");
   Project_Tools.Release_Checks.Require_File (Checks, "src/messages.ads");
   Project_Tools.Release_Checks.Require_File (Checks, "tests/tests.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/conformance.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/src/check_conformance.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/manifest.txt");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/message_format.render");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/plurals.render");
   Project_Tools.Release_Checks.Require_File (Checks, "examples/examples.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "examples/EXPECTED_OUTPUT.md");
   Project_Tools.Release_Checks.Require_File (Checks, "examples/catalogs/messages.catalog");
   Project_Tools.Release_Checks.Require_File (Checks, "benchmarks/benchmarks.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "benchmarks/render_benchmarks.adb");

   Check_AI_JSON_Metadata;
   Check_Generated_Artifacts;
   Run_Release_Builds;

   if Errors = 0 then
      Put_Line ("messages release checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Put_Line
        (Standard_Error,
         "messages release checks failed:" & Natural'Image (Errors) & " error(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Check_Messages;
