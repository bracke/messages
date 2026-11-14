with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Messages.Consistency;

--  Check a catalogue from a command line, so a project needs no Ada of its own
--  to have the rule.
--
--    catalog_check share/app/messages.catalog \
--      --verbatim=--help,--version,install,appname \
--      --locale-only=meta.
--
--  Exit status is 1 when something was found that would reach a user: a key
--  with no original, an argument dropped or invented, a token that did not
--  survive translation, an apostrophe ICU reads as an escape. Text identical to
--  the original is reported and does not fail: two words coincide between
--  languages often enough that failing on it would teach people to ignore the
--  check.
--
--  A locale kept in a file of its own is checked together with the catalogue
--  holding its default locale, and a check can be narrowed to the arguments
--  each message takes, which the rest of the rules do not disturb:
--
--    catalog_check share/locales/app-de.catalog \
--      --base=share/app.catalog --arguments-only
procedure Catalog_Check is
   use Ada.Text_IO;

   Max_Tokens : constant := 64;
   type Token_Store is array (1 .. Max_Tokens) of Unbounded_String;

   Verbatim       : Token_Store;
   Verbatim_Count : Natural := 0;
   Locale_Only       : Token_Store;
   Locale_Only_Count : Natural := 0;

   Catalog : Unbounded_String;
   Base    : Unbounded_String;

   --  Only Argument_Dropped and Argument_Added findings, with --arguments-only.
   Arguments_Only : Boolean := False;
   Serious : Natural := 0;
   Notes   : Natural := 0;

   procedure Split_Into
     (Value : String; Into : in out Token_Store; Count : in out Natural)
   is
      From : Positive := Value'First;
   begin
      while From <= Value'Last loop
         declare
            Stop : Natural :=
              Ada.Strings.Fixed.Index (Value (From .. Value'Last), ",");
         begin
            if Stop = 0 then
               Stop := Value'Last + 1;
            end if;

            if Stop > From and then Count < Max_Tokens then
               Count := Count + 1;
               Into (Count) := To_Unbounded_String (Value (From .. Stop - 1));
            end if;
            From := Stop + 1;
         end;
      end loop;
   end Split_Into;

   procedure Usage is
   begin
      Put_Line (Standard_Error,
                "usage: catalog_check <catalog> [--verbatim=a,b] "
                & "[--locale-only=prefix,] [--base=<catalog>] "
                & "[--arguments-only]");
   end Usage;

   --  The text of the file at Path, a LF after each line; Readable is False
   --  when it cannot be read.
   procedure Read (Path : String; Text : out Unbounded_String;
                   Readable : out Boolean)
   is
      File : File_Type;
   begin
      Text := Null_Unbounded_String;
      Open (File, In_File, Path, Form => "shared=no");
      while not End_Of_File (File) loop
         Append (Text, Get_Line (File) & ASCII.LF);
      end loop;
      Close (File);
      Readable := True;
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         Readable := False;
   end Read;
begin
   for Index in 1 .. Ada.Command_Line.Argument_Count loop
      declare
         Argument : constant String := Ada.Command_Line.Argument (Index);
      begin
         if Ada.Strings.Fixed.Index (Argument, "--verbatim=") = 1 then
            Split_Into
              (Argument (Argument'First + 11 .. Argument'Last),
               Verbatim, Verbatim_Count);
         elsif Ada.Strings.Fixed.Index (Argument, "--locale-only=") = 1 then
            Split_Into
              (Argument (Argument'First + 14 .. Argument'Last),
               Locale_Only, Locale_Only_Count);
         elsif Ada.Strings.Fixed.Index (Argument, "--base=") = 1 then
            Base := To_Unbounded_String
              (Argument (Argument'First + 7 .. Argument'Last));
         elsif Argument = "--arguments-only" then
            Arguments_Only := True;
         elsif Argument'Length > 0 and then Argument (Argument'First) = '-' then
            Usage;
            Ada.Command_Line.Set_Exit_Status (2);
            return;
         else
            Catalog := To_Unbounded_String (Argument);
         end if;
      end;
   end loop;

   if Length (Catalog) = 0 then
      Usage;
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   declare
      Findings : Messages.Consistency.Report;
      Only     : constant Messages.Consistency.Kind_Set :=
        (if Arguments_Only
         then [Messages.Consistency.Argument_Dropped
               | Messages.Consistency.Argument_Added => True,
               others => False]
         else Messages.Consistency.All_Kinds);
   begin
      if Length (Base) = 0 then
         Messages.Consistency.Check_File
           (Path        => To_String (Catalog),
            Verbatim    => Messages.Consistency.Token_Array
                             (Verbatim (1 .. Verbatim_Count)),
            Locale_Only => Messages.Consistency.Token_Array
                             (Locale_Only (1 .. Locale_Only_Count)),
            Into        => Findings,
            Only        => Only);
      else
         --  The default locale's catalogue first: it names the default
         --  locale and holds the originals the locale is checked against.
         declare
            Base_Text, Locale_Text : Unbounded_String;
            Base_Read, Locale_Read : Boolean;
         begin
            Read (To_String (Base), Base_Text, Base_Read);
            Read (To_String (Catalog), Locale_Text, Locale_Read);
            if not Base_Read or else not Locale_Read then
               Put_Line
                 (Standard_Error,
                  "cannot read "
                  & (if Base_Read then To_String (Catalog)
                     else To_String (Base)));
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
            Messages.Consistency.Check_Text
              (Source_Name => To_String (Catalog),
               Text        => To_String (Base_Text & Locale_Text),
               Verbatim    => Messages.Consistency.Token_Array
                                (Verbatim (1 .. Verbatim_Count)),
               Locale_Only => Messages.Consistency.Token_Array
                                (Locale_Only (1 .. Locale_Only_Count)),
               Into        => Findings,
               Only        => Only);
         end;
      end if;

      for Index in 1 .. Findings.Count loop
         Serious := Serious + 1;
         Put_Line
           (Standard_Error,
            Messages.Consistency.Image (Findings.Items (Index)));
      end loop;
      Notes := Findings.Identical;

      if Findings.Overflow then
         Put_Line (Standard_Error,
                   "more findings than the report holds; fix these and run again");
         Serious := Serious + 1;
      end if;

      if Notes > 0 then
         Put_Line
           (Notes'Image & " string(s) identical to the default locale"
            & " -- untranslated, or coincidence");
      end if;

      if Serious = 0 then
         Put_Line (To_String (Catalog) & ": consistent");
      else
         Ada.Command_Line.Set_Exit_Status (1);
      end if;
   end;
end Catalog_Check;
