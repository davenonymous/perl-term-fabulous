requires 'perl', '5.024';    # postfix dereference (->@*) is stable from 5.24

requires 'Clay::XS';
requires 'Data::Checks', '0.04';
requires 'Encode';
requires 'Exporter';
requires 'Feature::Compat::Try';
requires 'I18N::Langinfo';
requires 'IO::Async';
requires 'List::Util', '1.33';    # any, all (1.33), pairmap (1.29)
requires 'Object::Pad', '0.825';
requires 'Object::Pad::FieldAttr::Checked';
requires 'Object::PadX::Enum';
requires 'POSIX';
requires 'Scalar::Util';
requires 'Text::KDL::XS';
requires 'Time::HiRes';
requires 'Time::Local', '1.30';    # timelocal_posix
requires 'Unicode::GCString';
requires 'XSLoader';

on test => sub {
	requires 'Test2::V0';
};

# The documentation tools in tools/ (make docs, make docs-check).
on develop => sub {
	requires 'IO::Pty';
	requires 'JSON::PP';
	requires 'Pod::Markdown';
	recommends 'Imager';    # PNG output of tools/screenshot
};
