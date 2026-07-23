with Ada.Text_IO;
with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Empty_Message is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "empty.message", Args);
   begin
      Example_Support.Print_Status ("empty message status", Result);
      Ada.Text_IO.Put_Line ("empty message length:" & Natural'Image (Result.Text.Length));
   end;
end Empty_Message;
