requires 'perl', '5.024';    # postfix dereference (->@*) is stable from 5.24

requires 'Clay::XS';
requires 'Data::Checks', '0.04';
requires 'Encode';
requires 'Exporter';
requires 'FFI::Platypus', '2.00';
requires 'Feature::Compat::Try';
requires 'I18N::Langinfo';
requires 'IO::Async';
requires 'List::Util', '1.29';    # pairmap
requires 'Object::Pad', '0.825';
requires 'Object::Pad::FieldAttr::Checked';
requires 'Object::PadX::Enum';
requires 'POSIX';
requires 'Scalar::Util';
requires 'Termbox', '2';
requires 'Text::KDL::XS';
requires 'Unicode::GCString';

on test => sub {
	requires 'Test2::V0';
};
