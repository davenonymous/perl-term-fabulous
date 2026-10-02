use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Find qw(find);

# Build the META "provides" map by hand. Module::Metadata does not
# recognise Object::Pad's "class NAME" declarations, so the generated
# map would list those files as package "main"; an explicit map lets
# PAUSE index the dist from META alone.
sub collectProvides {
	my %provides;
	find(
		{
			no_chdir => 1,
			wanted   => sub {
				return unless /\.pm\z/;
				my ($package, $version) = readPackageAndVersion($_);
				$provides{$package} = {file => $_, version => $version};
			},
		},
		'lib'
	);
	return \%provides;
}

sub readPackageAndVersion {
	my ($file) = @_;
	open(my $fh, '<', $file) or die sprintf("Cannot read %s: %s\n", $file, $!);
	my ($package, $version);
	while (my $line = <$fh>) {
		$package //= $1 if $line =~ /^\s*(?:package|class|role|enum)\s+([\w:]+)/;
		$version //= $1 if $line =~ /^\s*our\s+\$VERSION\s*=\s*'([^']*)'/;
		last if defined $package && defined $version;
	}
	close($fh);
	die sprintf("No package or class declaration found in %s\n", $file) unless defined $package;
	die sprintf("No \$VERSION found in %s\n", $file) unless defined $version;
	return ($package, $version);
}

WriteMakefile(
	DISTNAME           => 'Term-Fabulous',
	NAME               => 'Term::Fabulous',
	AUTHOR             => 'davenonymous <perl@davenonymous.com>',
	VERSION_FROM       => 'lib/Term/Fabulous.pm',
	ABSTRACT_FROM      => 'lib/Term/Fabulous.pm',
	LICENSE            => 'perl_5',
	MIN_PERL_VERSION   => '5.024',
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => '6.64',
	},
	TEST_REQUIRES => {
		'Test2::V0' => '0',
	},
	PREREQ_PM => {
		'Clay::XS'                        => '0',
		'Data::Checks'                    => '0.04',
		'Encode'                          => '0',
		'Exporter'                        => '0',
		'FFI::Platypus'                   => '2.00',
		'Feature::Compat::Try'            => '0',
		'I18N::Langinfo'                  => '0',
		'IO::Async'                       => '0',
		'List::Util'                      => '1.29',
		'Object::Pad'                     => '0.825',
		'Object::Pad::FieldAttr::Checked' => '0',
		'Object::PadX::Enum'              => '0',
		'POSIX'                           => '0',
		'Scalar::Util'                    => '0',
		'Termbox'                         => '2',
		'Text::KDL::XS'                   => '0',
		'Time::HiRes'                     => '0',
		'Unicode::GCString'               => '0',
	},
	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources   => {
			homepage   => 'https://github.com/davenonymous/perl-term-fabulous',
			bugtracker => { web => 'https://github.com/davenonymous/perl-term-fabulous/issues' },
			repository => {
				type => 'git',
				url  => 'https://github.com/davenonymous/perl-term-fabulous.git',
				web  => 'https://github.com/davenonymous/perl-term-fabulous',
			},
		},
		dynamic_config => 0,
		provides       => collectProvides(),
	},
	test  => { TESTS => 't/*.t' },
	clean => { FILES => 'Term-Fabulous-*' },
);

sub MY::postamble {
	return <<'MAKE_FRAG';

# --- README regeneration ---------------------------------------------
# Usage: make readme
#
# README.md is the GitHub-facing rendering of the pod in Fabulous.pm;
# it is not shipped in the dist (see MANIFEST.SKIP), so distcheck
# cannot flag drift. Regenerate it after any pod change.

.PHONY: readme

readme :
	@command -v pod2markdown >/dev/null 2>&1 || { \
	    echo "ERROR: pod2markdown not found in PATH; cpanm Pod::Markdown"; \
	    exit 1; \
	}
	pod2markdown lib/Term/Fabulous.pm > README.md

# --- Release target -------------------------------------------------
# Usage: make release
#
# Tests the dist via `make disttest`, builds the tarball via
# `make dist` (disttest alone only creates the unpacked directory),
# then uploads it to CPAN with cpan-upload (from CPAN::Uploader).
# Refuses to run if the git working tree is dirty, if any module's
# $VERSION differs from the one in lib/Term/Fabulous.pm, or if a tag
# for the current $(VERSION) already exists. See RELEASING.md.
#
# disttest and dist run as separate sub-makes on purpose: as
# prerequisites of one target they would share a single distdir
# build, and the tarball would pack the blib/ that disttest left
# behind. PAUSE refuses to index such a tarball.

.PHONY: release release-check version-check

version-check :
	@perl -ne 'if (/^\s*our \$$VERSION\s*=\s*\x27([^\x27]*)\x27/ && $$1 ne "$(VERSION)") { print "ERROR: $$ARGV has \$$VERSION $$1, expected $(VERSION)\n"; $$failed = 1 } END { exit($$failed ? 1 : 0) }' $$(find lib -name '*.pm')

release-check : version-check
	@git diff-index --quiet HEAD -- || { \
	    echo "ERROR: git working tree is dirty; commit or stash first."; \
	    exit 1; \
	}
	@if git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null; then \
	    echo "ERROR: tag v$(VERSION) already exists; bump \$$VERSION in lib/Term/Fabulous.pm and the other modules."; \
	    exit 1; \
	fi
	@command -v cpan-upload >/dev/null 2>&1 || { \
	    echo "ERROR: cpan-upload not found in PATH; cpanm CPAN::Uploader"; \
	    exit 1; \
	}
	@test -r $(HOME)/.pause || { \
	    echo "ERROR: ~/.pause not found; see RELEASING.md for the format."; \
	    exit 1; \
	}

release :: release-check
	$(MAKE) disttest
	$(MAKE) dist
	@test -f $(DISTVNAME).tar.gz || { \
	    echo "ERROR: $(DISTVNAME).tar.gz was not built; refusing to upload."; \
	    exit 1; \
	}
	@if tar tzf $(DISTVNAME).tar.gz | grep -qE '/(blib/|Makefile$$|MYMETA\.|pm_to_blib)'; then \
	    echo "ERROR: $(DISTVNAME).tar.gz contains build artefacts; refusing to upload."; \
	    exit 1; \
	fi
	cpan-upload $(DISTVNAME).tar.gz
	@echo
	@echo "Uploaded $(DISTVNAME).tar.gz to PAUSE."
	@echo "Next:"
	@echo "  git tag -a v$(VERSION) -m 'Release v$(VERSION)'"
	@echo "  git push --follow-tags"
MAKE_FRAG
}
