with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Locale_Fallback is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "name", "Ada");
   Messages.Arguments.Set (Args, "count", "3");

   declare
      Exact_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de-AT", "hello", Args);
      Parent_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de-AT", "cart.items", Args);
      Default_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "fr-CA", "fallback.only", Args);
   begin
      Example_Support.Print_Result ("exact de-AT", Exact_Result);
      Example_Support.Print_Result ("parent de", Parent_Result);
      Example_Support.Print_Result ("default en", Default_Result);
   end;
end Locale_Fallback;
