with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Domain_Formatting is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   Messages.Arguments.Set (Args, "seconds", "3661");
   Messages.Arguments.Set (Args, "size", "1649267441664");
   Messages.Arguments.Set (Args, "distance", "1.5");
   Messages.Arguments.Set (Args, "offset", "-3");
   Messages.Arguments.Set (Args, "items", "red|green|blue");

   declare
      Duration : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.duration", Args);
      Bytes : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.bytes", Args);
      Unit : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.unit", Args);
      Rate : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.rate", Args);
      Short_Rate : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.short_rate", Args);
      Relative : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.relative", Args);
      Relative_De : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de", "domain.relative", Args);
      List : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "domain.list", Args);
      List_De : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de", "domain.list", Args);
   begin
      Example_Support.Print_Result ("domain duration", Duration);
      Example_Support.Print_Result ("domain bytes", Bytes);
      Example_Support.Print_Result ("domain unit", Unit);
      Example_Support.Print_Result ("domain rate", Rate);
      Example_Support.Print_Result ("domain short rate", Short_Rate);
      Example_Support.Print_Result ("domain relative", Relative);
      Example_Support.Print_Result ("domain relative de", Relative_De);
      Example_Support.Print_Result ("domain list", List);
      Example_Support.Print_Result ("domain list de", List_De);
   end;
end Domain_Formatting;
