with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Nested_Message_Render is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "gender", "female");
   Messages.Arguments.Set (Args, "name", "Grace");
   Messages.Arguments.Set (Args, "count", "2");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "upload.summary", Args);
   begin
      Example_Support.Print_Result ("nested select/plural", Result);
   end;
end Nested_Message_Render;
