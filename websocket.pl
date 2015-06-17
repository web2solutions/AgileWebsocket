#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite;
use DateTime;
use JSON qw(decode_json encode_json from_json to_json);
use Data::Dumper;

use Mojo::Redis;
use Protocol::Redis::XS;


my $clients = {};


get '/pub' => sub{
   my $pubsub = Mojo::Redis->new;
   $pubsub->publish(topic => 'foo',sub{$pubsub});
   shift->render(text=>'published')
};

websocket '/' => sub {
    my $self = shift;
    app->log->debug('WebSocket opened');




    my $ws = $self->tx;
    #$ws->send('xxxxxxxxxx');





    my $user_id;
    my $topic = '$dhx.socket';
    my $channel = '$dhx.socket.channel';
    $self->inactivity_timeout(300);




    $self->on(message => sub {
        my ($self, $msg) = @_;
        my $msg_hash = from_json( $msg );
        my $message = $msg_hash->{message} || 'empty message';
        my $action = $msg_hash->{action} || 'none';
        my $target = $msg_hash->{target} || 'none';
        my $name = $msg_hash->{name} || 'none';
        my $status = $msg_hash->{status} || 'success';
        my $record = $msg_hash->{record} ? $msg_hash->{record} : {};
        my $record_id = $msg_hash->{record_id} ? $msg_hash->{record_id} : -1;
        my $old_record = $msg_hash->{old_record} ? $msg_hash->{old_record} : {};

        my @records = ($msg_hash->{records}) ? @{$msg_hash->{records}} : ();
        my $time_zone = $msg_hash->{time_zone} || 'America/Sao_Paulo';
        my $wallpaper = $msg_hash->{wallpaper} || '';

        $topic = $msg_hash->{topic};

        $user_id = $msg_hash->{user_id} || '6';


        #my $records = $msg_hash->{records} || [];
        if ( $action eq 'set user' ) {
            #$clients->{$user_id} = $self->tx;
            my $pubsub = Mojo::Redis->new;
            $pubsub->protocol_redis("Protocol::Redis::XS");
            $pubsub->timeout(180);

            $self->stash(pubsub_redis => $pubsub);

            $pubsub->subscribe(''.$channel.'' => sub{
               my ($redis, $event) = @_;
               $ws->send($event->[2]);
               say join(', ', @$event);
            });


            #$pubsub->unsubscribe([''.$topic.''], sub {});
        }
        else
        {
            my $date = DateTime->now( time_zone => $time_zone);

            my $msg_hash = {
                        time => $date->hms,
                        message => $message,
                        action => $action,
                        target => $target,
                        origin => 'server',
                        name => $name,
                        status => $status,
                        topic => $topic,
                        user_id => $user_id,
                        records => [@records],
                        record_id => $record_id,
                        record => $record,
                        old_record => $old_record,
                        wallpaper => $wallpaper
            };

            #for (keys %$clients) {
            #    $clients->{$_}->send({json => {
            #            time => $date->hms,
            #            message => $message,
            #            action => $action,
            #            target => $target,
            #            name => $name,
            #            status => $status,
            #            user_id => $user_id
            #    }});
            #}
            my $pubsub = Mojo::Redis->new;
            $pubsub->publish(''.$channel.'' => to_json( $msg_hash ), sub{$pubsub});
            say to_json( $msg_hash );
        }
    });

    $self->on(finish => sub {
        app->log->debug('Client disconnected');
        #delete $clients->{$user_id};
    });



    Mojo::IOLoop->recurring(50 => sub{
				 my $pubsub = Mojo::Redis->new;
         $pubsub->publish(''.$channel.'' => '{ "message" : "keep alive"}', sub{$pubsub});
    });
};


my $port = 4000;
app->start('daemon', '--listen' => "http://*:$port");
