with Ada.Environment_Variables;

package body Messages.Program_Locale is

   function Language_Of (Identifier : String) return String is
      Last : Natural := Identifier'First - 1;
   begin
      for Index in Identifier'Range loop
         exit when Identifier (Index) in '.' | '@' | '_' | '-';
         Last := Index;
      end loop;

      declare
         Language : constant String := Identifier (Identifier'First .. Last);
      begin
         if Language = "C" or else Language = "POSIX" then
            return "";
         end if;
         return Language;
      end;
   end Language_Of;

   function Choose
     (LC_All      : String;
      LC_Messages : String;
      Lang        : String;
      Native      : String)
      return String
   is
      Raw : constant String :=
        (if LC_All /= "" then LC_All
         elsif LC_Messages /= "" then LC_Messages
         else Lang);
   begin
      if Raw /= "" then
         --  The user said something: a language, or C/POSIX, which is English.
         declare
            Language : constant String := Language_Of (Raw);
         begin
            return (if Language = "" then "en" else Language);
         end;
      end if;

      declare
         Language : constant String := Language_Of (Native);
      begin
         return (if Language = "" then "en" else Language);
      end;
   end Choose;

   function Detected (Native : String) return String is
      function Env (Name : String) return String is
        (if Ada.Environment_Variables.Exists (Name)
         then Ada.Environment_Variables.Value (Name)
         else "");
   begin
      return Choose
        (LC_All      => Env ("LC_ALL"),
         LC_Messages => Env ("LC_MESSAGES"),
         Lang        => Env ("LANG"),
         Native      => Native);
   end Detected;

end Messages.Program_Locale;
