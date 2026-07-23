with Ada.Text_IO;
with Example_Support;
with Example_Trace_Callbacks;
with Messages.Arguments;
with Messages.Diagnostics;
with Messages.Result;
with Messages.Runtime;

procedure Diagnostics_Non_Interference is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "name", "Ada");

   Messages.Diagnostics.Set_Trace_Callback (Example_Trace_Callbacks.Raising_Callback'Access);

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Result ("trace callback cannot affect render", Result);
      Ada.Text_IO.Put_Line
        ("diagnostic count:" & Natural'Image (Messages.Diagnostics.Length (Result.Diagnostics)));
   end;

   Messages.Diagnostics.Set_Trace_Callback (null);
end Diagnostics_Non_Interference;
