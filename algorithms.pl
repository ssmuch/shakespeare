use strict;
use warnings;
use Data::Dumper;

# Fork play
# my $child = fork();

# if ($child) {
#   # Parent block
#   sleep 6;
#   print "The child process is $child\n";
#   my $ret = waitpid($child, WHANG)
# }
# elsif ($child == 0) {
#   print "I am a child, $$";
# }
# else {
#   print "Failed to fork";
# }

my @a = (2, 4, 6, 1, 5, 3);
print recursivesum(@a);

sub recursivesum {
	my @arr = @_;
	my $len = scalar(@arr);

	if ($len > 1) {
		return pop(@arr) + recursivesum(@arr);
	}
	else {
		return $arr[0];
	}
}

sub countList {}



#Quick - divide and conquer
sub quickSort {
  	my @arr = @_;
  	my $len = scalar(@arr);

  	if ($len>1) {
    	my $key = $arr[0];
    	my (@arr_a, @arr_b);
    	for (my $i=1; $i<$len; $i++) {
      	if ($arr[$i] < $key) {
        		push(@arr_a, $arr[$i]);
      	}
      	else {
        		push(@arr_b, $arr[$i]);
      	}
    	}

    	@arr_a = quickSort(@arr_a);
    	@arr_b = quickSort(@arr_b);

    	push(@arr_a, $key);
		push(@arr_a, @arr_b);

    	return @arr_a;
  	}
  	else {
    	return @arr;
  	}
}

#Merge
sub merge {
  my $left_ref  = shift;
  my $right_ref = shift;
  my @tmp_arr;

  while (scalar(@$left_ref) and scalar(@$right_ref)) {
    my $tmp = $left_ref->[0] < $right_ref->[0] ? shift @$left_ref : shift @$right_ref;
    push(@tmp_arr, $tmp)
  }

  if (scalar @$right_ref) {
    foreach (@$right_ref) {
      push(@tmp_arr, $_);
    }
  }

  if (scalar @$left_ref) {
    foreach (@$left_ref) {
      push(@tmp_arr, $_);
    }
  }

  return @tmp_arr;
}

sub mergeSort {
  my @arr = @_;
  my $len = scalar @arr;

  my $mid = $len/2;

  if ($mid < 1) {
    return @arr;
  }

  my @left  = splice(@arr, 0, $mid);
  my @right = @arr;

  @left  = mergeSort(@left);
  @right = mergeSort(@right);

  @arr = merge(\@left, \@right);
  return @arr;
}

# Bubbles
sub bubbleSort {
  my @array = @_;
  my $len   = scalar @array;

  for (my $i=0; $i < $len - 1; $i++) {
    for (my $j=$i+1; $j < $len; $j++) {
      if ($array[$i] > $array[$j]) {
        my $tmp = $array[$i];
        $array[$i] = $array[$j];
        $array[$j] = $tmp;
      }
    }
  }
  return @array;
}

#Insert
sub insertSort {
  my @a = @_;
  my $len = scalar(@a);

  for (my $i=1; $i<$len; $i++) {
    my $insert = $a[$i];
    for (my $j=$i-1; $j>=0 && $a[$j]>$insert; $j--) {
      $a[$j+1] = $a[$j];
      $a[$j]   = $insert;
    }
  } 
  return @a;
}

# The next depend on last number
#print(countAndSay(5));

sub countAndSay {
   my $len = shift;

   my %map = (
      '1' => 11,
      '2' => 12,
      '3' => 13,
      '11'=> 21,
      '111'=> 31,
   );
   my $reg = "111|11|1|2|3";

   if ($len == 1) {
      return 1;
   }
   else {
       my $str = countAndSay($len - 1);
       my $last;

       LOOP:
       if ($str =~ /^($reg)/) {
          $last .= $map{$1};
          $str   = $';

          if (defined $str) {
            goto LOOP;
          }
       }
      return $last;
   }
}

sub search {
   my $target = shift;
   my @array  = @_;
   my $i = 0;

   foreach (@array) {
      if ($_ == $target) {
         return $i;
      }
      ++ $i;
   }
   return -1;
}

sub anagrams {
   my @strs = @_;
   my %hash;

   foreach (@strs) {
      my $key = join('', sort(split(//, $_)));
      if (exists($hash{$key})) {
         ++ $hash{$key};
      }
      else {
         $hash{$key} = 1;
      }
   }

   return \%hash;
}

sub mergeSortedArray {
   my $arrayA_ref = shift;
   my $arrayB_ref = shift;

   my $start = scalar @$arrayA_ref - scalar @$arrayB_ref;
   my $i = 0;

   for (;$start < scalar @$arrayA_ref; ++$start) {
      $arrayA_ref->[$start] = $arrayB_ref->[$i];
      ++ $i;
   }

   return $arrayA_ref;
}

sub removeDuplicates {
   my @a = @_;

   my %tmp;
   foreach (@_) {
      $tmp{$_} = '';
   }

   return scalar(keys(%tmp));
}



sub findMax {
   my $str = shift;
   
   my @a   = split (//, $str);
   my $sum = shift @a;

   foreach (@a) {
      if ($_ == 1 or $sum == 1 or  $sum == 0) {
         $sum += $_;
      }
      else {
         $sum *= $_;
      }
   }

   return $sum;
}

sub twoSum {
   my $target = shift;
   my @nums   = @_;
   my $len    = $#nums;
   my ($i, $j);

   for ($i=0; $i < $len; $i ++) {
      for ($j=$i+1; $j < $len; $j++) {
         if ($nums[$i] + $nums[$j] == $target) {
            print $i+1;  
            print $j+1;
            exit;
         }
      }
   }

   return 0;
}

sub f{
   my $n = shift;

   if ($n == 1 or $n == 0) {
      return 1;
   }
   else {
      return f($n-1) + f($n-2);
   }
}