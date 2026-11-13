with Ada.Strings.Unbounded;

with Messages.Arguments;
with Messages.Program_Locale;
with Messages.Result;
with Messages.Runtime;

package body Messages.Program_Catalog is
   use Ada.Strings.Unbounded;

   Catalog     : Messages.Runtime.Instance;
   Locale      : Unbounded_String := To_Unbounded_String ("en");
   Initialized : Boolean := False;

   procedure Ensure_Initialized is
   begin
      if not Initialized then
         Messages.Runtime.Initialize (Catalog, Catalog_Path);
         Locale := To_Unbounded_String (Messages.Program_Locale.Detected (Native_Locale));
         Initialized := True;
      end if;
   end Ensure_Initialized;

   function Language return String is
   begin
      Ensure_Initialized;
      return To_String (Locale);
   end Language;

   function Text (Key : String) return String is
      use type Messages.Result.Render_Status;
      Args : Messages.Arguments.Arguments;
   begin
      Ensure_Initialized;

      declare
         Result : constant Messages.Result.Render_Result :=
           Messages.Runtime.Render
             (Item      => Catalog,
              Locale    => To_String (Locale),
              Key       => Key,
              Arguments => Args);
      begin
         if Result.Status = Messages.Result.Success then
            return Messages.Result.Output_Text (Result.Text);
         end if;
      end;

      --  Key absent from the catalogue: return it unchanged.
      return Key;
   end Text;

end Messages.Program_Catalog;
