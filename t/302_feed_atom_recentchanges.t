use strict;
use Wiki::Toolkit::TestConfig::Utilities;
use Wiki::Toolkit;
use URI::Escape;

use Test::More tests =>
  (3 + 11 * $Wiki::Toolkit::TestConfig::Utilities::num_stores);

use_ok( "Wiki::Toolkit::Feed::Atom" );

eval { my $atom = Wiki::Toolkit::Feed::Atom->new; };
ok( $@, "new croaks if no wiki object supplied" );

eval {
        my $atom = Wiki::Toolkit::Feed::Atom->new( wiki => "foo" );
     };
ok( $@, "new croaks if something that isn't a wiki object supplied" );

my %stores = Wiki::Toolkit::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
  SKIP: {
      skip "$store_name storage backend not configured for testing", 11
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = Wiki::Toolkit->new( store => $store );
      my %default_config = (
              wiki => $wiki,
              site_name => "Wiki::Toolkit Test Site",
              make_node_url => sub {
                                     my $id = uri_escape($_[0]);
                                     my $version = $_[1] || '';
                                     $version = uri_escape($version) if $version;
                                     "http://example.com/?id=$id;version=$version";
                                   },
              recent_changes_link => "http://example.com/?RecentChanges",
              atom_link => "http://example.com/?action=rc;format=atom",
      );
      my $atom = eval {
          Wiki::Toolkit::Feed::Atom->new( %default_config, site_url => "http://example.com/kakeswiki/" );
      };
      is( $@, "",
         "'new' doesn't croak if wiki object and mandatory parameters supplied"
      );
      isa_ok( $atom, "Wiki::Toolkit::Feed::Atom" );

      my $feed = eval { $atom->recent_changes; };
      is( $@, "", "->recent_changes doesn't croak" );

      # Check the things that are generated by the mandatory arguments.
      like( $feed, qr|<link href="http://example.com/\?id=Test%20Node%201;version=1" />|,
	    "make_node_url is used" );

      # Check stuff that comes from the metadata.
      like( $feed, qr|<author><name>Kake</name></author>|,
	    "username picked up as author" );

      like( $feed, qr|<summary>.*\[nou]</summary>|,
            "username included in summary" );

      # Test the 'items' parameter.
      $feed = $atom->recent_changes( items => 2 );
      unlike( $feed, qr|<title>Test Node 1</title>|, "items param works" );

      # Test the 'days' parameter.
      $feed = $atom->recent_changes( days => 2 );
      like( $feed, qr|<title>Old Node</title>|, "days param works" );

      # Test ignoring minor changes.
      $feed = $atom->recent_changes( ignore_minor_edits => 1 );
      unlike( $feed, qr|This is a minor change.|,
              "ignore_minor_edits works" );

      # Test personalised feeds.
      $feed = $atom->recent_changes(
                                    filter_on_metadata => {
                                                            username => "Kake",
                                                          },
                                  );
      unlike( $feed, qr|<author>nou</author>|,
	      "can filter on a single metadata criterion" );
      $feed = $atom->recent_changes(
                                    filter_on_metadata => {
                                                      username => "Kake",
                                                      locale   => "Bloomsbury",
                                                          },
                                  );
      unlike( $feed, qr|<title>Test Node 1</title>|,
             "can filter on two criteria" );
  }
}