with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Basic_Render is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render
          (Item      => Runtime,
           Locale    => "en",
           Key       => "hello",
           Arguments => Args);
   begin
      Example_Support.Print_Result ("basic", Result);
   end;
end Basic_Render;
