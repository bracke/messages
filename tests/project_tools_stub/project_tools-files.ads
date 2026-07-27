package Project_Tools.Files is

   procedure Write_Text_File (Path : String; Text : String);

   --  The host's scratch directory, without a trailing separator: $TMPDIR /
   --  $TMP / $TEMP if set, else /tmp when it exists, else the current
   --  directory. Tests stage catalog fixtures here rather than a literal
   --  "/tmp", which does not exist on Windows.
   function Temp_Dir return String;

end Project_Tools.Files;
