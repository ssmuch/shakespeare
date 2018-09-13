# Crab imges from site xxgege.net/
# This is a study project, just for fun.
# Date: 2018/1/3
# Last Modified: 2018/1/31
# Author: Kyle Li

use strict;
use warnings;

use lib './lib';
use Data::Dumper;
use Encode;
use File::Fetch;
use Getopt::Long;
use HTTP::Tiny;
use threads;
use threads::shared;
use utf8;

use Md5Hash;
use Utilities;

my %imgdb : shared;

# Fork another thread to get rid of duplicated img
async {
   system "perl bin/dd.pl";
};

# Tie the md5 to local disk file
if (not -d 'db/') {
   mkdir('db');
}

my $base = "https://xxgege.net";
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
   $freq = 10;
}

if (not defined($mode) or
   $mode !~ /^(detach|join)$/i) {
   $mode = 'detach'
}

if (defined($rand)) {
   $html = Utilities::grab_html_by_rand($url, $page);
}
else {
   $html = Utilities::grab_html_by_sque($url, $page);
}

my %info    = Utilities::parse_items($html);

my $img_dir = encode('gbk', '图片');

if (not -e $img_dir) {
   mkdir($img_dir) or die "Failed to mkdir $img_dir";
}

#print Dumper \%info;
# Main loop for crawling the target
while (my ($link, $name) = each %info) {
   # Get the last index of the item page
   my $to_dir  = encode('gbk', '图片/' . $name);
   my $content = Utilities::grab_html($base . $link);
   my $index   = Utilities::get_last_index($content);

   # Looping to get all the links for the item
   if ($index > 1) {
      for(my $i=2; $i <= $index; ++$i) {
         my $next  = $base . $link . "index$i" . ".html";
         $content .= Utilities::grab_html($next);
      }
   }

   my @links = Utilities::parse_img_links($content);
   #print Dumper \@links;
   my $ff;
   my $thr;
   my $img_file;
   my @imgs;
   my $url;
   my $md5;

   # Reload the img hash db
   tie %imgdb, 'Md5Hash', 'db/imgdb.yml' or
	warn "Failed to tie imgdb file, $!\n";

   foreach (@links) {
      $url      = encode('utf-8', $_);

      if ($url !~ /^http/i) {
            $url = "http:" . $url;
      }

      $ff       = File::Fetch->new(uri => $url);
      $img_file = $to_dir . '/' . $ff->file;
      $md5      = Utilities::get_md5_by_name($img_file);
      #print $url . "\n";

      # if md5 existed
      if (exists $imgdb{$md5}) {
	   next;
      }
	else {
         $imgdb{$md5} = decode('gbk', $img_file);
	}

      $thr = async {
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