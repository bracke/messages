with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Fallback_Chain is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "name", "Ada");
   Messages.Arguments.Set (Args, "count", "3");

   declare
      Region_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de-AT", "hello", Args);
      Parent_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de-AT", "cart.items", Args);
      Default_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de-AT", "fallback.only", Args);
   begin
      Example_Support.Print_Result ("fallback de-AT exact", Region_Result);
      Example_Support.Print_Result ("fallback de parent", Parent_Result);
      Example_Support.Print_Result ("fallback default en", Default_Result);
   end;
end Fallback_Chain;
