# Crab imges from site xxgege.net/
# This is a study project, just for fun.
# Date: 2018/1/3
# Last Modified: 2018/1/19
# Author: Kyle Li

use strict;
use warnings;

use lib './lib';
use Cwd;
use Data::Dumper;
use Digest::MD5;
use Encode;
use File::Basename;
use File::Find;
use File::Fetch;
use File::Spec;
use Getopt::Long;
use HTTP::Tiny;
use threads;
use threads::shared;
use utf8;

use Md5Hash;

my %imgdb : shared;

# Defined the clean sub while control + C was called to stop the 
# script
$SIG{INT} = sub {
   untie %imgdb;
   tie %imgdb, 'Md5Hash', 'db/imgdb.yml';
   foreach (keys %imgdb) {
      if (not -e encode('gbk', $imgdb{$_})) {
         delete $imgdb{$_};
      }
   }

   chdir(encode('gbk', '图片'));
   my @dirs = glob "*";
   find(\&wanted, @dirs);
   finddepth(sub{rmdir},'.');

   exit(0);
};

# Remove those incompleted and blank ones
# Under detached mode the scripts could not clean some unfinished
# images, as they are die abnormally along with the main thread
# who was sent INT signal
sub wanted {
   m/.*\.jpg-.*/i && unlink($_);
   m/.*\.php/i && unlink($_);
   m/.*\.jpg/i && -z && unlink($_);
}

# Tie the md5 to local disk file
if (not -d 'db/') {
   mkdir('db');
}
tie %imgdb, 'Md5Hash', 'db/imgdb.yml' 
or die "Failed to tie file to Md5Hash"; 


my $base = "http://xxgege.net";
my @arts = qw/artyz artzp artjq artkt artwm artmt artyd/;

my $html;
my $url;

my $help;
my $rand;
my $art;
my $page;
my $freq;
my $mode;

my %options = (
   'help'   => \$help,
   'rand'   => \$rand,
   'art=s'  => \$art,
   'page=i' => \$page,
   'freq=i' => \$freq,
   'mode=s' => \$mode
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

if (not defined($page)) {
   $page = 3;
}

if (not defined($freq)) {
   $freq = 3;
}

if (not defined($mode) or
    $mode !~ /^(detach|join)$/i) {
   $mode = 'detach'
}

if (defined($rand)) {
   $html = grab_html_by_rand($url, $page);
}
else {
   $html = grab_html_by_sque($url, $page);
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
   my $img_file;
   my @imgs;
   my $url;
   my $md5;

   foreach (@links) {
      $url      = encode('utf-8', $_);
      $ff       = File::Fetch->new(uri => $url);
      $img_file = $to_dir . '/' . $ff->file;
      $thr      = async {
         # Read the img hash db
         untie %imgdb;
         tie %imgdb, 'Md5Hash', 'db/imgdb.yml';
         my $flag = 0;
         RETRY:
            eval { 
               $ff->fetch(to => $to_dir); 
            };

            # Try 3 times if fetch failed
            if ($@ and $flag < 3) {
               $flag ++;
               goto RETRY;
            }

            if (-e $img_file) {
               $md5 = get_md5($img_file);
               if (exists $imgdb{$md5}) {
                  unlink($img_file);
               }  
               else {
                  $imgdb{$md5} = decode('gbk', $img_file);
               }
            }
       };
      
      if ($mode eq 'detach') {
         $thr->detach();
      }
      else {
         $thr->join();
      }

      # To avoid aggressive spawning thread which consuming too much resources
      # You could comment this line if you are with a powerful machine
      sleep(int rand($freq));
   }
   print "$to_dir\n";
}

#================================================
# Subroutines 
#================================================
sub help {
   print encode('gbk',"
   $0 - 抓取脚本, 你懂的 
   本脚本主要用于抓取图片，网站 http://xxgege.net, 本程序用多个线程来抓取，本地建立
   md5样本库，用于去掉重复图片，由于无法在服务器端获取md5值，目前采取下载到本地然后在
   本地库内遍历，看是否已存在，若是，即删除之。

   可以使用 Control + c 来停止脚本
   选项：
      -art [artyz artzp artjq artkt artwm artmt artyd]
      -rand 随机抓取
      -page 抓取页数，默认为3页
      -freq 抓取频率, 这是一个随机数，默认区间0-3秒, 输入数字
      -mode 线程模式，[detach|join], 
            detach : 不关心创建出来的抓取线程的死活, 理论上会快点
            join   : 会等待并回收创建出来的线程, 理论上慢点
      -help 帮助文档
   
   内容映射：
      artyz - 艳照
      artzp - 自拍
      artjq - 激情
      artkt - 卡通
      artwm - 唯美
      artmt - 美腿
      artyd - 银荡
   
   例子：
      perl $0 -art artzp -rand -page 5 -freq 1
      perl $0 -rand -mod detach
      perl $0
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
   @links = split(/src=/, encode('gbk', $html));

   @links = grep {/upload|image|img|sezuzu/} @links;
   @links = map  {$_ =~ s/.*(http.*jpg).*/$1/g;  $_;} @links;
   @links = grep {/^http.*jpg$/} @links;

   return @links;
}

# get md5 of image
sub get_md5 {
   my $img = shift;
   my $ctx = Digest::MD5->new();
   my $file_handle;
   
   open($file_handle, '<', $img) or
   die "Failed to open $img";
   $ctx->addfile($file_handle);
   close($file_handle);

   return $ctx->hexdigest;
}