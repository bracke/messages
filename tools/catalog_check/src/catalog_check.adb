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
procedure Catalog_Check is
   use Ada.Text_IO;

   Max_Tokens : constant := 64;
   type Token_Store is array (1 .. Max_Tokens) of Unbounded_String;

   Verbatim       : Token_Store;
   Verbatim_Count : Natural := 0;
   Locale_Only       : Token_Store;
   Locale_Only_Count : Natural := 0;

   Catalog : Unbounded_String;
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
                & "[--locale-only=prefix,]");
   end Usage;
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
   begin
      Messages.Consistency.Check_File
        (Path        => To_String (Catalog),
         Verbatim    => Messages.Consistency.Token_Array
                          (Verbatim (1 .. Verbatim_Count)),
         Locale_Only => Messages.Consistency.Token_Array
                          (Locale_Only (1 .. Locale_Only_Count)),
         Into        => Findings);

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
