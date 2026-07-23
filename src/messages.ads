--  Root namespace for ICU-style message formatting, built on the I18N platform.
--
--  The stable public API is this root package plus:
--  * Messages.Runtime, Messages.Result, Messages.Diagnostics, Messages.Arguments
--
--  Parser, validator, compiler, IR, AST, cache, buffer, renderer, and formatter
--  implementation packages are internal and not part of the compatibility
--  contract. Locale/plural/number/date data comes from the I18N platform crate.
package Messages is
   pragma Preelaborate;
end Messages;
