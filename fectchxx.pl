use strict;
use warnings;
use File::Basename;
use File::Find;
use File::Fetch;
use File::Spec;
use HTTP::Tiny;
use threads;
use Data::Dumper;
use Cwd;
use Encode;
use utf8;

# Crab img from site xxgege.net/
# Only interested on following categroy [artyz, artzp, artjq, artkt]
# You could replace the category url, this just script just for fun 
# Date: 2018/1/3
# Author: Kyle Li

my $url  = "http://xxgege.net/artyz/";
my $base = "http://xxgege.net";

my $html = grab_html_by_limit($url);
my %info = parse_items($html);

my $img_dir = encode('gbk', '图片');
if (not -e $img_dir) {
   mkdir($img_dir) or die "Failed to mkdir $img_dir";
}

# remove those unfinished images 
$SIG{INT} = sub {
   chdir(encode('gbk', '图片'));
   my @dirs = glob "*";
   find(\&wanted, @dirs);

   exit(0);
};

sub wanted {
   m/.*-.*/i && unlink($_);
}

chdir(encode('gbk', '图片')) or die "Failed to changedir to imgs";

while (my ($link, $name) = each %info) {
   # Get the last index of the item page
   my $to_dir  = encode('gbk', $name);
   my $content = grab_html($base . $link);
   my $index   = get_last_index($content);

   # Looping to get all the links for the item
   if ($index > 1) {
     for(my $i=2; $i <= $index; ++$i) {
       my $next  = $base . $link . "index$i" . ".html";
       $content .= grab_html($next);
    }
   }

   my @links = parse_img_links($content);
   my $ff;
   my $thr;
   my $img_name;
   my @imgs;
   my $url;
   my $flg = 0;

   foreach (@links) {
     $url = encode('utf-8', $_);
     $ff  = File::Fetch->new(uri => $url);
     $thr = async {
         RETRY:
         eval { 
            $ff->fetch(to => $to_dir); 
         };
         if ($@) {
            goto RETRY;
         }
       };
     $thr->detach();
     ++$flg;

     # To avoid aggressive spawning thread which consuming too much resources
     # You could comment this line if you are with a powerful machine
     sleep(rand(8));
   }
   print "$to_dir : $flg \n";
}

sub grab_html {
   my $url = shift;
   my $r   = HTTP::Tiny->new->get($url);

   # Decoding the charset
   return decode('utf-8', $r->{content});
}

# Grab the html recursively
sub grab_html_by_limit {
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
   @links = split(/src=/, encode('gbk', $html));

   @links = grep {/imghost|sezuzu|image/} @links;
   @links = map  {$_ =~ s/.*(http.*jpg).*/$1/g;  $_;} @links;
   @links = grep {/^http.*jpg$/} @links;

   return @links;
}