#!/usr/bin/perl

use FindBin qw($Bin);
use Plack::Request;

use strict;
use Test::More;# tests => 38;
use Test::RDF;
use RDF::Trine qw[iri literal blank variable statement];
use Log::Log4perl qw(:easy);
use Module::Load::Conditional qw[can_load];

Log::Log4perl->easy_init( { level   => $FATAL } ) unless $ENV{TEST_VERBOSE};

my $file = $Bin . '/data/basic.ttl';

BEGIN {
    use_ok('RDF::LinkedData');
    use_ok('RDF::Helper::Properties');
    use_ok('RDF::Trine::Parser');
    use_ok('RDF::Trine::Model');
}



my $parser     = RDF::Trine::Parser->new( 'turtle' );
my $model = RDF::Trine::Model->temporary_model;
my $base_uri = 'http://localhost';
$parser->parse_file_into_model( $base_uri, $file, $model );

ok($model, "We have a model");

my $ec;
if (can_load( modules => { 'RDF::Endpoint' => 0.03 })) {
	$ec = {endpoint_path => '/sparql'} ;
}

my $ld = RDF::LinkedData->new(model => $model, base=>$base_uri, endpoint_config => $ec);

isa_ok($ld, 'RDF::LinkedData');
cmp_ok($ld->count, '>', 0, "There are triples in the model");


{
	note "Get /foo, ensure nothing changed.";
	$ld->request(Plack::Request->new({}));
	my $response = $ld->response($base_uri . '/foo');
	isa_ok($response, 'Plack::Response');
	is($response->status, 303, "Returns 303");
	like($response->header('Location'), qr|/foo/data$|, "Location is OK");
}

{
    note "Get /foo/data";
    $ld->type('data');
    my $response = $ld->response($base_uri . '/foo');
    isa_ok($response, 'Plack::Response');
    is($response->status, 200, "Returns 200");
	 my $model = return_model($response->content, $parser);
    has_literal('This is a test', 'en', undef, $model, "Test phrase in content");
 SKIP: {
		skip "No endpoint configured", 2 unless ($ld->has_endpoint);
		pattern_target($model);
		pattern_ok(
					  statement(
									iri($base_uri . '/foo/data'),
									iri('http://rdfs.org/ns/void#inDataset'),
									variable('void')
								  ),
					  statement(
									variable('void'),
									iri('http://rdfs.org/ns/void#sparqlEndpoint'),
									iri($base_uri . '/sparql'),
								  )
					 )
	}
}

done_testing;


sub return_model {
	my ($content, $parser) = @_;
	my $model = RDF::Trine::Model->temporary_model;
	$parser->parse_into_model( $base_uri, $content, $model );
	return $model;
}
