package Utilities;

use strict;
use warnings;

use Digest::MD5;
use Encode;
use File::Basename;
use HTTP::Tiny;
use utf8;

sub grab_html {
   my $url = shift;
   my $r   = HTTP::Tiny->new->get($url);

   # Decoding the charset
   return decode('utf-8', $r->{content});
}

sub grab_html_href {
   my $url = shift;

   my $r;

   eval {
        $r = HTTP::Tiny->new->get($url);
   };

   if ($@) {
       return "";
   }

   my $html;
   # Decoding the charset
   my @lines  = split(/\n/, $r->{content});
   foreach my $line (@lines) {
       chomp($line);

       next if $line !~ /src|href/i;
       $html .= $line . "\n";
   }

   return decode('utf-8', $html);
}

# Grab page by_rand
sub grab_html_by_rand {
   my $url   = shift;
   my $limit = shift;

   # Set a default limit for grabbing html
   if (not defined($limit)) {
      $limit = 10;
   }

   my $html = grab_html_href($url);
   my $last = get_last_index($html);
   my $i    = 0;

   my %rands;
   my $r;

   while ($i < $limit) {
      ++ $i;
      $r = int rand($last);
      if ($r == 0 or exists $rands{$r}) {
         ++ $limit;
         next;
      }

      $rands{$r} = 1;
   }

   foreach (keys %rands) {
      my $link = $url . "/index" . $_ . ".html";
      $html   .= grab_html_href($link);
   }

   return decode('utf-8', $html);
}

# Grab the html in a loop
sub grab_html_by_sque {
   my $url   = shift;
   my $limit = shift;

   # Set a default limit for grabbing html
   if (not defined($limit)) {
      #$limit = 10;
      $limit = get_last_index_by_href($url);
   }

   # Get start page
   if ($url !~ /http.*index.*(\d+)\.html/) {
      $url .= "/index1.html";
   }

   my $curr_page   = basename($url);
   my $base_link   = dirname($url);
   my $start_index = ($curr_page =~ /index(\d+)\.html/) ? $1 : 1;
   my $html        = grab_html_href($url);
   my $last_index  = get_last_index($html);
   $last_index     = ($start_index + $limit  < $last_index) ?
                     ($start_index + $limit) : $last_index;

   while ($start_index < $last_index) {
      ++ $start_index;
      $url   = $base_link . "/" . "index$start_index" . ".html";
      $html .= grab_html_href($url);
   }

   return $html;
}

sub get_last_index {
   my $content = shift;
   if (defined $content and $content =~ /尾(\d+)页/ig) {
      return $1;
   }
   else {
       return 0;
   }
}

sub get_last_index_by_href {
    my $url  = shift;
    my $html = grab_html_href($url);

    return get_last_index($html);
}

# Retrieve itemm and link map for the next grab
sub parse_items {
   my $html = shift;
   my %info;

   # split the items out of the raw content
   LOOP:
   if ($html =~ /<a href="(.*)" target="_blank" title="(.*)"/) {
      my $name  = $1;
      my $title = $2;

      $info{$name} = $title;
      $html = $';
      if (defined $html) {
         goto LOOP;
      }
   }

   return %info;
}

sub parse_img_links {
   my $html = shift;
   my @links;

   return if not defined $html;
   # Split the img links for download
   @links = split(/src="/, encode('gbk', $html));

   @links = grep {/upload|image|img|sezuzu/} @links;
   @links = map  {$_ =~ s/(.*jpg).*/$1/g;  $_;} @links;
   @links = grep {/^.*jpg$/} @links;

   return @links;
}

# get md5 from image name
sub get_md5_by_name {
   my $img = shift;
   my $ctx = Digest::MD5->new();
   $ctx->add($img);

   return $ctx->hexdigest;
}

# get md5 from image file
sub get_md5_by_file {
   my $img = shift;
   my $ctx = Digest::MD5->new();
   my $file_handle;
   open($file_handle, '<', $img) or warn "Failed to open $img, $!\n";
   $ctx->addfile($file_handle);
   close $file_handle;

   return $ctx->hexdigest;
}

# Locate the dups
sub locate_dups {
   my $db_ref = shift;

   my @dups;
   my $dup_ref = {};

   foreach (keys %{$db_ref}) {
      push @{$dup_ref->{$db_ref->{$_}}}, $_;
   }

   foreach (keys %{$dup_ref}) {
      if (scalar @{$dup_ref->{$_}} >= 2) {
         pop @{$dup_ref->{$_}};

         push @dups, @{$dup_ref->{$_}};
      }
   }

   return map {$_ => 1} @dups;
}

1;
