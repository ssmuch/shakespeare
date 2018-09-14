package DbUtil;

use DBI;

sub connectDb {
   my $database = shift;
   my $driver   = "SQLite"; 

   if (not defined $database) {
      $database = "db/xxgege.db";
   }

   my $dsn = "DBI:$driver:dbname=$database";
   my $dbh = DBI->connect($dsn, "", "", { RaiseError => 1 }) 
      or die $DBI::errstr;

   return $dbh;
}

sub query {
   my $dbh = shift;
   my $sql = shift;

   my $sth = $dbh->prepare($sql);
   my $rv = $sth->execute() or die $DBI::errstr;
   my @rows;

   if($rv < 0){
      print $DBI::errstr;
   }

   while(my @result = $sth->fetchrow_array()) {
      if ((scalar @result) == 1) {
         push(@rows, $result[0]);
      }
      else {
         push(@rows, @result);
      }
   }
   return @rows;
}

sub execute {
   my $dbh = shift;
   my $sql = shift;

   eval {
      my $rv = $dbh->do($sql);
   };

   if ($@) {
      return 1;
   }

   return 0;
}

sub closeDb {
   my $dbh = shift;
   $dbh->disconnect();
}

1;