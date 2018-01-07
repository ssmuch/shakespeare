# Crab imges from site xxgege.net/
# This is a study project, just for fun.
# Date: 2018/1/3
# Author: Kyle Li

use strict;
use warnings;

use Cwd;
use Data::Dumper;
use Encode;
use File::Basename;
use File::Find;
use File::Fetch;
use File::Spec;
use Getopt::Long;
use HTTP::Tiny;
use threads;
use utf8;

# Defined the clean sub while control + C was called to stop the 
# script
$SIG{INT} = sub {
   chdir(encode('gbk', '图片'));
   my @dirs = glob "*";
   find(\&wanted, @dirs);

   exit(0);
};

# Remove those incompleted and blank ones
sub wanted {
   m/.*-.*/i && unlink($_);
   #m/.*\.jpg/i && (-s $_) == 0 && unlink($_);
}

my $base = "http://xxgege.net";
my @arts = qw/artyz artzp artjq artkt artwm artmt artyd/;

my $html;
my $url;

my $help;
my $rand;
my $art;

my %options = (
   'help' => \$help,
   'rand' => \$rand,
   'art=s'=> \$art
);

GetOptions(%options);

if (defined($help)) {
   help();
}

# Initalize $art
if (not defined($art) or not grep {$_ eq $art} @arts) {
   my $index = int rand (scalar @arts);
   $art      = $arts[$index];
}

$url  = $base . '/' . $art;

if (defined($rand)) {
   $html = grab_html_by_rand($url, 3);
}
else {
   $html = grab_html_by_sque($url, 3);
}

my %info    = parse_items($html);
my $img_dir = encode('gbk', '图片');

if (not -e $img_dir) {
   mkdir($img_dir) or die "Failed to mkdir $img_dir";
}

# Main loop for crawling the target
while (my ($link, $name) = each %info) {
   # Get the last index of the item page
   my $to_dir  = encode('gbk', '图片/' . $name);
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
      sleep(int rand(20));
   }
   print "$to_dir : $flg \n";
}

#================================================
# Subroutines 
#================================================
sub help {
   print encode('gbk',"
   $0 - 抓取脚本, 你懂的 
   本脚本主要用于抓取图片，网站 http://xxgege.net
   用法：
      -art [artyz artzp artjq artkt artwm artmt artyd]
      -rand 随机抓取
      -help 帮助文档
   
   内容映射：
      artyz - 艳照
      artzp - 自拍
      artjq - 激情
      artkt - 卡通
      artwm - 唯美
      artmt - 美腿
      artyd - 银荡
   ");
   exit;
}

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

# Grab the html recursively
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
   @links = split(/src=/, encode('gbk', $html));

   @links = grep {/upload|image|img|sezuzu/} @links;
   @links = map  {$_ =~ s/.*(http.*jpg).*/$1/g;  $_;} @links;
   @links = grep {/^http.*jpg$/} @links;

   return @links;
}