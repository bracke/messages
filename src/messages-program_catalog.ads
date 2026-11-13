--  A program's own message catalogue, rendered in the user's language.
--
--  What every program that ships a catalogue wrote for itself, byte for byte
--  apart from its name: one runtime, initialized on first use from the
--  program's catalogue file, rendering in the language Program_Locale picks,
--  and handing a key back unchanged when the catalogue has nothing for it.
--
--  Where the catalogue file is and what the host's own locale is are the
--  program's to say -- the first is found beside its executable, the second
--  comes from a platform layer this crate does not depend on -- so both are
--  formal functions, each called once, on the first Text.
generic
   --  The catalogue file to load.
   with function Catalog_Path return String;
   --  The host's native locale (Hostkit.Host.Native_Locale), "" for none.
   with function Native_Locale return String;
package Messages.Program_Catalog is

   --  The localized text for a catalogue Key, with no arguments.
   --
   --  @param Key A catalogue key, such as "app.name".
   --  @return The rendered text, or Key itself when the catalogue has none.
   function Text (Key : String) return String;

   --  The language the catalogue renders in (initializing it if need be).
   --
   --  @return A language subtag, such as "en" or "de".
   function Language return String;

end Messages.Program_Catalog;
