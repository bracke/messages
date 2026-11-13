--  Which language a program's own message catalogue should speak.
--
--  A program that ships a catalogue (launcher, search, ...) has to pick the
--  locale it renders in before it renders anything, and every one of them had
--  the same answer written out again: LC_ALL, then LC_MESSAGES, then LANG,
--  cut down to the language and "en" for an empty, C or POSIX value. That
--  answer is only half right. The environment variables are a POSIX
--  convention; Windows and macOS keep the user's language in the host's own
--  settings and start a desktop program with none of them set, so every
--  program came up in English there whatever the user had chosen.
--
--  The host's own answer cannot be asked from here -- this crate does not
--  depend on a platform layer -- so the caller passes it in (Hostkit.Host.
--  Native_Locale, which is "" on Linux, where the environment is the answer).
--  An environment variable that is set still wins: it is how a user overrides
--  the desktop for one program, on every host.
package Messages.Program_Locale is

   --  The language part of a locale identifier, in either spelling the hosts
   --  use: "de_DE.UTF-8" and "de-AT" are "de", "sr@latin" is "sr". The POSIX
   --  "C" and "POSIX" locales name no language.
   --
   --  @param Identifier A locale identifier, as the environment or host spells it.
   --  @return The language subtag, or "" when Identifier names no language.
   function Language_Of (Identifier : String) return String;

   --  The language to render in, from the three POSIX variables' values and
   --  the host's native locale: the first variable that is set decides (and a
   --  C or POSIX value there means English); when none is set the native
   --  locale's language; "en" when that says nothing either.
   --
   --  @param LC_All The value of LC_ALL, or "".
   --  @param LC_Messages The value of LC_MESSAGES, or "".
   --  @param Lang The value of LANG, or "".
   --  @param Native The host's native locale (Hostkit.Host.Native_Locale), or "".
   --  @return A language subtag, never "".
   function Choose
     (LC_All      : String;
      LC_Messages : String;
      Lang        : String;
      Native      : String)
      return String;

   --  Choose, with the variables read from this process's environment.
   --
   --  @param Native The host's native locale, or "".
   --  @return A language subtag, never "".
   function Detected (Native : String) return String;

end Messages.Program_Locale;
