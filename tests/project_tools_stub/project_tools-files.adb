with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;

package body Project_Tools.Files is

   procedure Write_Text_File (Path : String; Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_Text_File;

   function Temp_Dir return String is
      function Env (Name : String) return String is
        (if Ada.Environment_Variables.Exists (Name)
         then Ada.Environment_Variables.Value (Name)
         else "");
   begin
      if Env ("TMPDIR") /= "" then
         return Env ("TMPDIR");
      elsif Env ("TMP") /= "" then
         return Env ("TMP");
      elsif Env ("TEMP") /= "" then
         return Env ("TEMP");
      elsif Ada.Directories.Exists ("/tmp") then
         return "/tmp";
      else
         return ".";
      end if;
   end Temp_Dir;

end Project_Tools.Files;

