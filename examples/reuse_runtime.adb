with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Reuse_Runtime is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   Messages.Arguments.Set (Args, "name", "Ada");
   declare
      First : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Result ("first render", First);
   end;

   Messages.Arguments.Clear (Args);
   Messages.Arguments.Set (Args, "count", "7");
   declare
      Second : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de", "cart.items", Args);
   begin
      Example_Support.Print_Result ("second render", Second);
   end;
end Reuse_Runtime;
