# -*- cperl -*-
# copyright (C) 2005 Topia <topia@clovery.jp>. all rights reserved.
# This is free software; you can redistribute it and/or modify it
#   under the same terms as Perl itself.
# $Id: Util.pm 82 2005-02-03 17:16:54Z topia $
# $URL: file:///usr/minetools/svnroot/mixi/trunk/WWW-Mixi-OO/lib/WWW/Mixi/OO/Util.pm $
package WWW::Mixi::OO::Util;
use strict;
use warnings;
use URI;
use Carp;
use POSIX;
use Hash::Case::Preserve;
our $regex_parts;
__PACKAGE__->_init_regex_parts;

=head1 NAME

WWW::Mixi::OO::Util - WWW::Mixi::OO Helper Functions

=head1 SYNOPSIS

  use base qw(WWW::Mixi::OO::Util);
  $this->absolute_uri(..., ...);

=head1 DESCRIPTION

misc helper functions.

=head1 METHODS

=over 4

=cut

=item absolute_uri

C<< ->absolute_uri($uri, [$base]); >>

Generate absolute URI from base uri.
This is simple wrapper for URI class.

=cut

sub absolute_uri {
    my ($this, $uri, $base) = @_;
    return do {
	if (defined $base) {
	    URI->new_abs($uri, $base)
	} else {
	    URI->new($uri);
	}
    };
}

=item relative_uri

C<< ->relative_uri($uri, [$base]); >>

Generate relative URI from base uri.
This is simple wrapper for URI class.

=cut

sub relative_uri {
    my ($this, $uri, $base) = @_;
    return  $this->absolute_uri($uri, $base)->rel($base);
}

=item remove_tag

C<< ->remove_tag($str); >>

Remove HTML(or XML, or SGML?) tag from string.

=cut

sub remove_tag {
    my ($this, $str) = @_;
    return undef unless defined $str;
    my $non_metas = $this->regex_parts->{non_metas};
    my $re_standard_tag = qr/
      <$non_metas
      (?:"[^\"]*"$non_metas|'[^\']*'$non_metas)*
      (?:>|(?=<)|$(?!\n))
    /x;
    my $re_comment_tag  = qr/<!
      (?:
       --[^-]*-
       (?:[^-]+-)*?-
       (?:[^>-]*(?:-[^>-]+)*?)??
      )*
      (?:>|$(?!\n)|--.*$)/x;
    my $re_html_tag     = qr/$re_comment_tag|$re_standard_tag/;
    $str =~ s/$re_html_tag//g;
    return $str;
}

=item html_attrs_to_hash

=cut

sub html_attrs_to_hash {
    my ($this, $str) = @_;
    my $html_attr = $this->regex_parts->{html_attr};

    map {
	if (/\A(.+?)=(.*)\z/) {
	    ($1, $this->unquote($2))
	} else {
	    ($_, undef);
	}
    } ($str =~ /($html_attr)(?:\s+|$)/go);
}

=item generate_ignore_case_hash

=cut

sub generate_ignore_case_hash {
    my $this = shift;
    tie my(%hash), 'Hash::Case::Preserve', keep => 'FIRST';
    %hash = @_;
    \%hash;
}

=item generate_case_preserved_hash

obsolete. renamed to generate_ignore_case_hash

=cut

sub generate_case_preserved_hash {
    shift->generate_ignore_case_hash(@_);
}

=item copy_hash_val

=cut

sub copy_hash_val {
    my $this = shift;
    my $src = shift;
    my $dest = shift;

    foreach (@_) {
	$dest->{$_} = $src->{$_} if exists $src->{$_};
    }
}

=item regex_parts

C<< ->regex_parts->{$foo}; >>

=cut

sub regex_parts {
    return $regex_parts;
}

sub _init_regex_parts {
    my $parts = $regex_parts ||= {};
    $$parts{non_meta} =
	qr/[^\"\'<>]/o;
    $$parts{non_metas} =
	qr/$$parts{non_meta}*/o;

    $$parts{non_meta_spc} =
	qr/[^\"\'<> ]/o;
    $$parts{non_meta_spcs} =
	qr/$$parts{non_meta_spc}*/o;

    $$parts{non_meta_spc_eq} =
	qr/[^\"\'<> =]/o;
    $$parts{non_meta_spc_eqs} =
	qr/$$parts{non_meta_spc_eq}*/o;

    $$parts{html_quotedstr_no_paren} =
	qr/"[^"]*"|'[^']*'/o;
    $$parts{html_quotedstr} =
	qr/(?:$$parts{html_quotedstr_no_paren})/o;
    $$parts{html_attrval} =
	qr/(?:$$parts{html_quotedstr_no_paren}|$$parts{non_meta_spcs})+/o;
    $$parts{html_attr} =
	qr/$$parts{non_meta_spc_eq}+(?:=$$parts{html_attrval})?/o;
    $$parts{html_attrs} =
	qr/(?>(?:$$parts{html_attr}(?:\s+|$))*)/o;
    $$parts{html_maybe_attrs} =
	qr/(?:\s+$$parts{html_attr})*/o;

}

=item escape

C<< ->escape($str); >>

equivalent of CGI::escapeHTML.

=cut

sub escape {
    my $this = shift;
    $_ = shift;
    return undef unless defined;
    s/\&(amp|quot|apos|gt|lt);/&amp;$1;/g;
    s/\&(?!(?:[a-zA-Z]+|#\d+|#x[a-f\d]+);)/&amp;/g;
    s/\"/&quot;/g;
    s/\'/&apos;/g;
    s/>/&gt;/g;
    s/</&lt;/g;
    return $_;
}

=item unescape

C<< ->unescape($str); >>

HTML unescape.

=cut

sub unescape {
    my $this = shift;
    $_ = shift;
    return undef unless defined;
    s/&quot;/\"/g;
    s/&apos;/\'/g;
    s/&gt;/>/g;
    s/&lt;/</g;
    s/&amp;/&/g;
    return $_;
}

=item unquote

C<< ->unquote($str); >>

HTML unquote.

=cut

sub unquote {
    my $this = shift;
    $_ = shift;
    if (/\A([\'\"])(.*)\1\Z/) {
	$this->unescape($2);
    } else {
	# none escaped
	$_;
    }
}

=item rewrite

C<< ->rewrite($str); >>

standard rewrite method.
do remove_tag and unescape.

=cut

sub rewrite {
    my $this = shift;
    $this->unescape($this->remove_tag(shift));
}

=item please_override_this

C<< sub foo { shift->please_override_this } >>

universal 'please override this' error method.

=cut

sub please_override_this {
    my $this = shift;
    (my $funcname = (caller(1))[3]) =~ s/^.*::(.+?)$/$1/;

    die sprintf 'please override %s->%s!', (ref $this || $this), $funcname;
}

1;

__END__
=back

=head1 SEE ALSO

L<WWW::Mixi::OO>

=head1 AUTHOR

Topia E<lt>topia@clovery.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Topia.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
