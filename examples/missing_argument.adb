with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Missing_Argument is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Status ("missing argument", Result);
   end;
end Missing_Argument;
