with Ada.Text_IO;
with Messages.Arguments;

procedure Argument_Lifecycle is
   Args : Messages.Arguments.Arguments;
begin
   Messages.Arguments.Set (Args, "name", "Ada");
   Ada.Text_IO.Put_Line
     ("has name after set: " & Boolean'Image (Messages.Arguments.Has (Args, "name")));
   Ada.Text_IO.Put_Line
     ("name value: " & Messages.Arguments.Get (Args, "name"));

   Messages.Arguments.Clear (Args);
   Ada.Text_IO.Put_Line
     ("has name after clear: " & Boolean'Image (Messages.Arguments.Has (Args, "name")));
end Argument_Lifecycle;
