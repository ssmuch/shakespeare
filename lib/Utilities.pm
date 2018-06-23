package Utilities;

use Digest::MD5;
use Encode;
use File::Basename;
use utf8;

sub grab_html {
   my $url = shift;
   my $r   = HTTP::Tiny->new->get($url);

   # Decoding the charset
   return decode('utf-8', $r->{content});
}

# Grab page by_rand
sub grab_html_by_rand {
   my $url   = shift;
   my $limit = shift;

   # Set a default limit for grabbing html
   if (not defined($limit)) {
      $limit = 10;
   }

   my $html = grab_html($url);
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
      $html   .= grab_html($link);
   }

   return $html;
}

# Grab the html in a loop
sub grab_html_by_sque {
   my $url   = shift;
   my $limit = shift;

   # Set a default limit for grabbing html
   if (not defined($limit)) {
      $limit = 10;
   }

   # Get start page
   if ($url !~ /http.*index.*(\d+)\.html/) {
      $url .= "/index1.html";
   }

   my $curr_page   = basename($url);
   my $base_link   = dirname($url);
   my $start_index = ($curr_page =~ /index(\d+)\.html/) ? $1 : 1;
   my $html        = grab_html($url);
   my $last_index  = get_last_index($html);
   $last_index     = ($start_index + $limit  < $last_index) ?
                     ($start_index + $limit) : $last_index;

   while ($start_index < $last_index) {
      ++ $start_index;
      $url   = $base_link . "/" . "index$start_index" . ".html";
      $html .= grab_html($url);
   }

   return $html;
}

sub get_last_index {
   my $content = shift;
   if ($content =~ /尾(\d+)页/ig) {
      return $1;
   }
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
   open(FH, '<', $img) or warn "Failed to open $img, $!\n";
   $ctx->addfile(FH);
   close FH;

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
