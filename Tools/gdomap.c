/* This is a simple name server for GNUstep Distributed Objects
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1996

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <stdio.h>
#include <stdlib.h>
#ifndef __WIN32__
#include <unistd.h>		/* for gethostname() */
#include <sys/param.h>		/* for MAXHOSTNAMELEN */
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>		/* for inet_ntoa() */
#endif /* !__WIN32__ */
#include <errno.h>
#include <limits.h>
#include <string.h>		/* for strchr() */
#ifndef __WIN32__
#include <sys/time.h>
#include <sys/resource.h>
#include <netdb.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/file.h>
/*
 *	Stuff for setting the sockets into non-blocking mode.
 */
#ifdef	__POSIX_SOURCE
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#include <netinet/in.h>
#include <net/if.h>
#ifndef	SIOCGIFCONF
#include <sys/ioctl.h>
#ifndef	SIOCGIFCONF
#include <sys/sockio.h>
#endif
#endif

#endif /* !__WIN32__ */

#include	"gdomap.h"
/*
 *	ABOUT THIS PROGRAM
 *
 *	This is a simple name server for GNUstep Distributed Objects
 *	The server program listens on a well known port (service name 'gdomap')
 *
 *	The officially assigned port is 538.  On most systems port numbers
 *	under 1024 can only be used by root (for security).  So this program
 *	needs to be run as root.
 *
 *	This is UNIX code - I have no idea how portable to other OSs it may be.
 *
 *	For detailed information about the communication protocol used - see
 *	the include file.
 */

/* For IRIX machines, which don't define this */
#ifndef        IPPORT_USERRESERVED
#define        IPPORT_USERRESERVED     5000
#endif /* IPPORT_USERRESERVED */

#define QUEBACKLOG	(16)	/* How many coonections to queue.	*/
#define	MAX_IFACE	(256)	/* How many network interfaces.		*/
#define	IASIZE		(sizeof(struct in_addr))

int	debug = 0;		/* Extra debug logging.			*/
int	nofork = 0;		/* turn off fork() for debugging.	*/
int	noprobe = 0;		/* turn off probe for unknown servers.	*/

int	udp_sent = 0;
int	tcp_sent = 0;
int	udp_read = 0;
int	tcp_read = 0;

struct in_addr	my_addr;	/* Set in init_iface()		*/
unsigned short	my_port;	/* Set in init_iface()		*/

/*
 *	Predeclare some of the functions used.
 */
static void	dump_stats();
static void	handle_accept();
static void	handle_io();
static void	handle_read(int);
static void	handle_recv();
static void	handle_request(int);
static void	handle_send();
static void	handle_write(int);
static void	init_iface();
static void	init_ports();
static void	init_probe();
static void	queue_msg(struct sockaddr_in* a, unsigned char* d, int l);
static void	queue_pop();
static void	queue_probe(struct in_addr* to, struct in_addr *from);

/*
 *	I have simple mcopy() and mzero() implementations here for the
 *	present because there seems to be a bug in the gcc 2.7.2.1
 *	memcpy() and memset() on SunOS 4.1.3 for sparc!
 */
static void
mcopy(void* p0, void* p1, int l)
{
    unsigned char*	b0 = (unsigned char*)p0;
    unsigned char*	b1 = (unsigned char*)p1;
    int			i;

    for (i = 0; i < l; i++) {
	b0[i] = b1[i];
    }
}

static void
mzero(void* p, int l)
{
    unsigned char*	b = (unsigned char*)p;

    while (l > 0) {
	*b++ = '\0';
	l--;
    }
}

/*
 *	Variables used for determining if a connection is from a process
 *	on the local host.
 */
int interfaces = 0;			/* Number of interfaces.	*/
struct in_addr addr[MAX_IFACE];		/* Address of each interface.	*/

static int
is_local_host(struct in_addr a)
{
    int	i;

    for (i = 0; i < interfaces; i++) {
	if (memcmp((char*)&a, (char*)&addr[i], sizeof(a)) == 0) {
	    return(1);
	}
    }
    return(0);
}

static int
is_local_net(struct in_addr a)
{
    int	i;
    int	net = inet_netof(a);

    for (i = 0; i < interfaces; i++) {
	if (net == inet_netof(addr[i])) {
	    return(1);
	}
    }
    return(0);
}

/*
 *	Variables used for handling non-blocking I/O on channels.
 */
int	tcp_desc = -1;		/* Socket for incoming TCP connections.	*/
int	udp_desc = -1;		/* Socket for UDP communications.	*/
fd_set	read_fds;		/* Descriptors which are readable.	*/
fd_set	write_fds;		/* Descriptors which are writable.	*/

struct	{
    struct sockaddr_in	addr;	/* Address of process making request.	*/
    int			pos;	/* Position reading data.		*/
    union {
	gdo_req		r;
	unsigned char	b[GDO_REQ_SIZE];
    } buf;
} r_info[FD_SETSIZE];		/* State of reading each request.	*/

struct	{
    int		len;		/* Length of data to be written.	*/
    int		pos;		/* Amount of data already written.	*/
    char*	buf;		/* Buffer for data.			*/
} w_info[FD_SETSIZE];

struct	u_data	{
    struct sockaddr_in	addr;	/* Address to send to.			*/
    int			pos;	/* Number of bytes already sent.	*/
    int 		len;	/* Length of data to send.		*/
    unsigned char*	dat;	/* Data to be sent.			*/
    struct u_data*	next;	/* Next message to send.		*/
} *u_queue = 0;
int	udp_pending = 0;

/*
 *	Name -		queue_msg()
 *	Purpose -	Add a message to the queue of those to be sent
 *			on the UDP socket.
 */
void
queue_msg(struct sockaddr_in* a, unsigned char* d, int l)
{
    struct u_data*	entry = (struct u_data*)malloc(sizeof(struct u_data));

    memcpy(&entry->addr, a, sizeof(*a));
    entry->pos = 0;
    entry->len = l;
    entry->dat = malloc(l);
    memcpy(entry->dat, d, l);
    entry->next = 0;
    if (u_queue) {
	struct u_data*	tmp = u_queue;

	while (tmp->next) tmp = tmp->next;
	tmp->next = entry;
    }
    else {
	u_queue = entry;
    }
    udp_pending++;
}

void
queue_pop()
{
    struct u_data*	tmp = u_queue;

    if (tmp) {
	u_queue = tmp->next;
	free(tmp->dat);
	free(tmp);
	udp_pending--;
    }
}

/*
 *	Primitive mapping stuff.
 */
unsigned short	next_port = IPPORT_USERRESERVED;

typedef struct {
    unsigned char*	name;	/* Service name registered.	*/
    unsigned int	port;	/* Port it was mapped to.	*/
    unsigned short	size;	/* Number of bytes in name.	*/
    unsigned char	net;	/* Type of port registered.	*/
    unsigned char	svc;	/* Type of port registered.	*/
} map_ent;

int	map_used = 0;
int	map_size = 0;
map_ent	**map = 0;

static int
compare(unsigned char* n0, int l0, unsigned char* n1, int l1)
{
    if (l0 == l1) {
	return(memcmp(n0, n1, l0));
    }
    else if (l0 < l1) {
	return(-1);
    }
    return(1);
}

/*
 *	Name -		map_add()
 *	Purpose -	Create a new map entry structure and insert it
 *			into the map in the appropriate position.
 */
static map_ent*
map_add(unsigned char* n, unsigned char l, unsigned int p, unsigned char t)
{
    map_ent	*m = (map_ent*)malloc(sizeof(map_ent));
    int		i;

    m->port = p;
    m->name = (char*)malloc(l);
    m->size = l;
    m->net = (t & GDO_NET_MASK);
    m->svc = (t & GDO_SVC_MASK);
    mcopy(m->name, n, l);

    if (map_used >= map_size) {
	if (map_size) {
	    map = (map_ent**)realloc(map, (map_size + 16)*sizeof(map_ent*));
	    map_size += 16;
	}
	else {
	    map = (map_ent**)malloc(16*sizeof(map_ent*));
	    map_size = 16;
	}
    }
    for (i = 0; i < map_used; i++) {
	if (compare(map[i]->name, map[i]->size, m->name, m->size) > 0) {
	    int	j;

	    for (j = map_used+1; j > i; j--) {
		map[j] = map[j-1];
	    }
	    break;
	}
    }
    map[i] = m;
    map_used++;
    if (debug > 2) {
	fprintf(stderr, "Added port %d to map for %.*s\n",
		m->port, m->size, m->name);
    }
    return(m);
}

/*
 *	Name -		map_by_name()
 *	Purpose -	Search the map for an entry for a particular name
 */
static map_ent*
map_by_name(unsigned char* n, int s)
{
    int		lower = 0;
    int		upper = map_used;
    int		index;

    if (debug > 2) {
	fprintf(stderr, "Searching map for %.*s\n", s, n);
    }
    for (index = upper/2; upper != lower; index = lower + (upper - lower)/2) {
	int	i = compare(map[index]->name, map[index]->size, n, s);

        if (i < 0) {
            lower = index + 1;
        } else if (i > 0) {
            upper = index;
        } else {
            break;
        }
    }
    if (index<map_used && compare(map[index]->name,map[index]->size,n,s) == 0) {
	if (debug > 2) {
	    fprintf(stderr, "Found port %d for %.*s\n", map[index]->port, s, n);
	}
	return(map[index]);
    }
    if (debug > 2) {
	fprintf(stderr, "Failed to find map entry for %.*s\n", s, n);
    }
    return(0);
}

/*
 *	Name -		map_del()
 *	Purpose -	Remove a mapping entry from the map and release
 *			the memory it uses.
 */
static void
map_del(map_ent* e)
{
    int	i;

    if (debug > 2) {
	fprintf(stderr, "Removing port %d from map for %.*s\n",
		e->port, e->size, e->name);
    }
    for (i = 0; i < map_used; i++) {
	if (map[i] == e) {
	    int	j;

	    free(e->name);
	    free(e);
	    for (j = i + 1; j < map_used; j++) {
		map[j-1] = map[j];
	    }
	    map_used--;
	    return;
	}
    }
}

/*
 *	Variables and functions for keeping track of the IP addresses of
 *	hosts which are running the name server.
 */
unsigned long	prb_used = 0;
unsigned long	prb_size = 0;
struct in_addr	**prb = 0;

/*
 *	Name -		prb_add()
 *	Purpose -	Create a new probe entry in the list in the
 *			appropriate position.
 */
static struct in_addr*
prb_add(struct in_addr *p)
{
    struct in_addr*	n = (struct in_addr*)malloc(IASIZE);
    int	i;

    mcopy(n, p, IASIZE);

    if (prb_used >= prb_size) {
	int	size = (prb_size + 16) * sizeof(struct in_addr*);

	if (prb_size) {
	    prb = (struct in_addr**)realloc(prb, size);
	    prb_size += 16;
	}
	else {
	    prb = (struct in_addr**)malloc(size);
	    prb_size = 16;
	}
    }
    for (i = 0; i < prb_used; i++) {
	if (memcmp((char*)prb[i], (char*)n, IASIZE) > 0) {
	    int	j;

	    for (j = prb_used+1; j > i; j--) {
		prb[j] = prb[j-1];
	    }
	    break;
	}
    }
    prb[i] = n;
    prb_used++;
    return(prb[i]);
}

/*
 *	Name -		prb_get()
 *	Purpose -	Search the list for an entry for a particular addr
 */
static struct in_addr*
prb_get(struct in_addr *p)
{
    int		lower = 0;
    int		upper = prb_used;
    int		index;

    for (index = upper/2; upper != lower; index = lower + (upper - lower)/2) {
	int	i = memcmp(prb[index], p, IASIZE);

        if (i < 0) {
            lower = index + 1;
        } else if (i > 0) {
            upper = index;
        } else {
            break;
        }
    }
    if (index<prb_used && memcmp(prb[index],p,IASIZE)==0) {
	return(prb[index]);
    }
    return(0);
}

/*
 *	Name -		prb_del()
 *	Purpose -	Remove an entry from the list.
 */
static void
prb_del(struct in_addr *p)
{
    int	i;

    for (i = 0; i < prb_used; i++) {
	if (memcmp(prb[i], p, IASIZE) == 0) {
	    int	j;

	    free(prb[i]);
	    for (j = i + 1; j < prb_used; j++) {
		prb[j-1] = prb[j];
	    }
	    prb_used--;
	    return;
	}
    }
}


/*
 *	Name -		clear_chan()
 *	Purpose -	Release all resources associated with a channel
 *			and remove it from the list of requests being
 *			serviced.
 */
static void
clear_chan(int desc)
{
    if (desc >= 0 && desc < FD_SETSIZE) {
	FD_CLR(desc, &write_fds);
	if (desc == tcp_desc || desc == udp_desc) {
	    FD_SET(desc, &read_fds);
	}
	else {
	    FD_CLR(desc, &read_fds);
	    close(desc);
	}
	if (w_info[desc].buf) {
	    free(w_info[desc].buf);
	    w_info[desc].buf = 0;
	}
	w_info[desc].len = 0;
	w_info[desc].pos = 0;
	mzero(&r_info[desc], sizeof(r_info[desc]));
    }
}

static void
dump_stats()
{
    int	tcp_pending = 0;
    int	i;

    for (i = 0; i < FD_SETSIZE; i++) {
	if (w_info[i].len > 0) {
	    tcp_pending++;
	}
    }
    fprintf(stderr, "tcp messages waiting for send - %d\n", tcp_pending);
    fprintf(stderr, "udp messages waiting for send - %d\n", udp_pending);
    fprintf(stderr, "size of name-to-port map - %d\n", map_used);
    fprintf(stderr, "number of known name servers - %d\n", prb_used);
    fprintf(stderr, "TCP %d read, %d sent\n", tcp_read, tcp_sent);
    fprintf(stderr, "UDP %d read, %d sent\n", udp_read, udp_sent);
}

/*
 *	Name -		init_iface()
 *	Purpose -	Establish our well-known port (my_port) and build up
 *			an array of the IP addresses supported on the network
 *			interfaces of this machine.
 *			The first non-loopback interface is presumed to be
 *			our primary interface and it's address is stored in
 *			the global variable 'my_addr'.
 */
static void
init_iface()
{
    struct servent	*sp;
    struct ifconf	ifc;
    struct ifreq	ifreq;
    struct ifreq	*ifr;
    struct ifreq	*final;
    char		buf[MAX_IFACE * sizeof(struct ifreq)];
    int			set_my_addr = 0;
    int			desc;

    /*
     *	First we determine the port for the 'gdomap' service - ideally
     *	this should be the default port, since we should have registered
     *	this with the appropriate authority and have it reserved for us.
     */
    my_port = htons(GDOMAP_PORT);
    if ((sp = getservbyname("gdomap", "tcp")) == 0) {
	fprintf(stderr, "Warning - unable to find service 'gdomap'\n");
    }
    else {
	unsigned short	tcp_port = sp->s_port;

	if ((sp = getservbyname("gdomap", "udp")) == 0) {
	    fprintf(stderr, "Warning - unable to find service 'gdomap'\n");
	}
	else if (sp->s_port != tcp_port) {
	    fprintf(stderr, "Warning - UDP and TCP service entries differ\n");
	    fprintf(stderr, "Warning - I will use the TCP entry for both!\n");
	}
	if (tcp_port != my_port) {
	    fprintf(stderr, "Warning - gdomap not running on normal port\n");
	}
	my_port = tcp_port;
    }

    if ((desc = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
	perror("socketf for init_iface");
	exit(1);
    }
    ifc.ifc_len = sizeof(buf);
    ifc.ifc_buf = buf;
    if (ioctl(desc, SIOCGIFCONF, (char*)&ifc) < 0) {
	perror("SIOCGIFCONF for init_iface");
	close(desc);
	exit(1);
    }

    /*
     *	Find the IP address of each active network interface.
     */
    final = (struct ifreq*)&ifc.ifc_buf[ifc.ifc_len];
    for (ifr = ifc.ifc_req; ifr < final; ifr++) {
	if (ifr->ifr_addr.sa_family == AF_INET) {	/* IP interface */
	    ifreq = *ifr;
	    if (ioctl(desc, SIOCGIFFLAGS, (char *) &ifreq) < 0) {
		perror("SIOCGIFFLAGS");
	    } else if (ifreq.ifr_flags & IFF_UP) {	/* active interface */
		if (ioctl(desc, SIOCGIFADDR, (char *) &ifreq) < 0) {
		    perror("SIOCGIFADDR");
		} else {
		    addr[interfaces] = ((struct sockaddr_in *)
					  & ifreq.ifr_addr)->sin_addr;
		    /*
		     *	First configured interface (excluding loopback) is
		     *	considered to be that of this servers primary address.
		     */
		    if (set_my_addr==0 && inet_netof(addr[interfaces])!=127) {
			my_addr = addr[interfaces];
		    }
		    interfaces++;
		}
	    }
	}
	if (interfaces >= MAX_IFACE) {
	    break;
	}
	/* Support for variable-length addresses. */
#ifdef HAS_SA_LEN
	ifr = (struct ifreq *) ((caddr_t) ifr
		      + ifr->ifr_addr.sa_len - sizeof(struct sockaddr));
#endif
    }
    close(desc);
}

/*
 *	Name -		init_ports()
 *	Purpose -	Set up the ports for accepting incoming requests.
 */
static void
init_ports()
{
    int		r;
    struct sockaddr_in	sa;

    /*
     *	Now we set up the sockets to accept incoming connections and set
     *	options on it so that if this program is killed, we can restart
     *	immediately and not find the socket addresses hung.
     */

    if ((udp_desc = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
	fprintf(stderr, "Unable to create UDP socket\n");
	exit(1);
    }
    r = 1;
    if ((setsockopt(udp_desc,SOL_SOCKET,SO_REUSEADDR,(char*)&r,sizeof(r)))<0) {
	fprintf(stderr, "Warning - unable to set 're-use' on UDP socket\n");
    }
    if ((r = fcntl(udp_desc, F_GETFL, 0)) >= 0) {
	r |= NBLK_OPT;
	if (fcntl(udp_desc, F_SETFL, r) < 0) {
	    fprintf(stderr, "Unable to set UDP socket non-blocking\n");
	    exit(1);
	}
    }
    else {
	fprintf(stderr, "Unable to handle UDP socket non-blocking\n");
	exit(1);
    }
    /*
     *	Now we bind our address to the socket and prepare to accept incoming
     *	connections by listening on it.
     */
    mzero(&sa, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = htonl(INADDR_ANY);
    sa.sin_port = my_port;
    if (bind(udp_desc, (void*)&sa, sizeof(sa)) < 0) {
	fprintf(stderr, "Unable to bind address to UDP socket\n");
	exit(1);
    }

    /*
     *	Now we do the TCP socket.
     */
    if ((tcp_desc = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0) {
	fprintf(stderr, "Unable to create TCP socket\n");
	exit(1);
    }
    r = 1;
    if ((setsockopt(tcp_desc,SOL_SOCKET,SO_REUSEADDR,(char*)&r,sizeof(r)))<0) {
	fprintf(stderr, "Warning - unable to set 're-use' on TCP socket\n");
    }
    if ((r = fcntl(tcp_desc, F_GETFL, 0)) >= 0) {
	r |= NBLK_OPT;
	if (fcntl(tcp_desc, F_SETFL, r) < 0) {
	    fprintf(stderr, "Unable to set TCP socket non-blocking\n");
	    exit(1);
	}
    }
    else {
	fprintf(stderr, "Unable to handle TCP socket non-blocking\n");
	exit(1);
    }
    mzero(&sa, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = htonl(INADDR_ANY);
    sa.sin_port = my_port;
    if (bind(tcp_desc, (void*)&sa, sizeof(sa)) < 0) {
	fprintf(stderr, "Unable to bind address to TCP socket\n");
	exit(1);
    }
    if (listen(tcp_desc, QUEBACKLOG) < 0) {
	fprintf(stderr, "Unable to listen for connections on TCP socket\n");
	exit(1);
    }

    /*
     *	Set up masks to say we are interested in these descriptors.
     */
    FD_ZERO(&read_fds);
    FD_ZERO(&write_fds);
    FD_SET(tcp_desc, &read_fds);
    FD_SET(udp_desc, &read_fds);

    /*
     *	Turn off pipe signals so we don't get interrupted if we attempt
     *	to write a response to a process which has died.
     */
    signal(SIGPIPE, SIG_IGN);
}

/*
 *	Name -		init_probe()
 *	Purpose -	Send a request to all hosts on the local network
 *			to see if there is a name server running on them.
 */
static void
init_probe()
{
    int	iface;

    if (debug > 2) {
	fprintf(stderr, "Initiating probe requests.\n");
    }
    for (iface = 0; iface < interfaces; iface++) {
	int	net = inet_netof(addr[iface]);
	int	me = inet_lnaof(addr[iface]);
	int	lo = 1;
	int	hi;
	int	i;

	if (net == 127) {
	    continue;		/* Don't probe loopback interface.	*/
	}
        prb_add(&addr[iface]);	/* Add self to server list.	*/

	/*
	 *	Determine the highest possible host number depending on
	 *	the class of network address in use.
	 */
	if ((net & 0xffffff00) == 0) {
	    hi = 0xffffff;			/* Class A	*/
	}
	else if ((net & 0xffff0000) == 0) {
	    hi = 0xffff;			/* Class B	*/
	}
	else {
	    hi = 0xff;				/* Class C	*/
	}

	/*
	 *	First kick off probes for known hosts unless we are
	 *	probing ALL hosts.
	 */
	if (noprobe || hi > 0xff) {
	    for (i = lo; i < hi; i++) {
		struct in_addr	a = inet_makeaddr(net, i);
		struct hostent*	hp;

		if (i == me) {
		    continue;	/* Don't probe self - that's silly.	*/
		}

		/*
		 *	See if there is a host known with this address,
		 *	if not we skip this one.
		 */
		hp = gethostbyaddr((const char*)&a, sizeof(a), AF_INET);
		if (hp == 0) {
		    continue;
		}
		queue_probe(&a, &addr[iface]);	/* Kick off probe.	*/
	    }
	}

	/*
	 *	Now start probes for servers on machines which may be on
	 *	the network, but are not known to this system.
	 *
	 *	We only do this on class 'C' networks since the number of
	 *	possible hosts on a class 'A' or 'B' network is far too
	 *	high to probe without causing network congestion.
	 */
	if (noprobe == 0 && hi <= 0xff) {
	    for (i = lo; i < hi; i++) {
		struct in_addr	a = inet_makeaddr(net, i);
		struct hostent*	hp;

		if (i == me) {
		    continue;	/* Don't probe self - that's silly.	*/
		}
		queue_probe(&a, &addr[iface]);	/* Kick off probe.	*/
	    }
	}
    }
    if (debug > 2) {
	fprintf(stderr, "Probe requests initiated.\n");
    }
}

/*
 *	Name -		handle_accept()
 *	Purpose -	Handle an incoming connection, setting up resources
 *			for the request. Ensure that the channel is in
 *			non-blocking mode so that we can't hang.
 */
static void
handle_accept()
{
    struct sockaddr_in	sa;
    int		len = sizeof(sa);
    int		desc;

    desc = accept(tcp_desc, (void*)&sa, &len);
    if (desc >= 0) {
	int	r;

	FD_SET(desc, &read_fds);
	r_info[desc].pos = 0;
	mcopy((char*)&r_info[desc].addr, (char*)&sa, sizeof(sa));

	if (debug) {
	    fprintf(stderr, "accept from %s(%d) to chan %d\n",
		inet_ntoa(sa.sin_addr), ntohs(sa.sin_port), desc);
	}
	/*
	 *	Ensure that the connection is non-blocking.
	 */
	if ((r = fcntl(desc, F_GETFL, 0)) >= 0) {
	    r |= NBLK_OPT;
	    if (fcntl(desc, F_SETFL, r) < 0) {
		if (debug) {
		    fprintf(stderr, "failed to set chan %d non-blocking\n",
				desc);
		}
		clear_chan(desc);
	    }
	}
	else {
	    if (debug) {
	        fprintf(stderr, "failed to set chan %d non-blocking\n", desc);
	    }
	    clear_chan(desc);
	}
    }
    else if (debug) {
	fprintf(stderr, "accept failed - errno %d\n", errno);
    }
}

/*
 *	Name -		handle_io()
 *	Purpose -	Main loop to handle I/O on multiple simultaneous
 *			connections.  All non-blocking stuff.
 */
static void
handle_io()
{
    struct timeval timeout;
    void	*to;
    int		rval = 0;
    int		i;
    fd_set	rfds;
    fd_set	wfds;

    while (rval >= 0) {
	rfds = read_fds;
	wfds = write_fds;
	to = 0;

	/*
	 *	If there is anything waiting to be sent on the UDP socket
	 *	we must check to see if it is writable.
	 */
	if (u_queue != 0) {
	    FD_SET(udp_desc, &wfds);
	}

	rval = select(FD_SETSIZE, &rfds, &wfds, 0, to);

	/*
	 *	Let's handle any error return.
	 */
	if (rval < 0) {
	    if (errno == EBADF) {
		fd_set	efds;

		/*
		 *	Almost certainly lost a connection - try each
		 *	descriptor in turn to see which one it is.
		 *	Remove descriptor from bitmask and close it.
		 *	If the error is on the listener socket we die.
		 */
		FD_ZERO(&efds);
		for (i = 0; i < FD_SETSIZE; i++) {
		    if (FD_ISSET(i, &rfds) || FD_ISSET(i, &wfds)) {
			FD_SET(i, &efds);
			timeout.tv_sec = 0;
			timeout.tv_usec = 0;
			to = &timeout;
			rval = select(FD_SETSIZE, &efds, 0, 0, to);
			FD_CLR(i, &efds);
			if (rval < 0 && errno == EBADF) {
			    clear_chan(i);
			    if (i == tcp_desc) {
				fprintf(stderr, "Fatal error on socket.\n");
				exit(1);
			    }
			}
		    }
		}
		rval = 0;
	    }
	    else {
		fprintf(stderr, "Interrupted in select.\n");
		exit(1);
	    }
	}

	for (i = 0; i < FD_SETSIZE; i++) {
	    if (FD_ISSET(i, &rfds)) {
		if (i == tcp_desc) {
		    handle_accept();
		}
		else if (i == udp_desc) {
		    handle_recv();
		}
		else {
		    handle_read(i);
		}
		if (debug > 2) {
		    dump_stats();
		}
	    }
	    if (FD_ISSET(i, &wfds)) {
		if (i == udp_desc) {
		    handle_send();
		}
		else {
		    handle_write(i);
		}
	    }
	}
    }
}

/*
 *	Name -		handle_read()
 *	Purpose -	Read a request from a channel.  This may be called in
 *			many stages if the read is blocking.
 */
static void
handle_read(int desc)
{
    unsigned char*	ptr = r_info[desc].buf.b;
    int	done = 0;
    int	r;

    while (r_info[desc].pos < GDO_REQ_SIZE && done == 0) {
	r = read(desc, &ptr[r_info[desc].pos], GDO_REQ_SIZE - r_info[desc].pos);
	if (r > 0) {
	    r_info[desc].pos += r;
	}
	else {
	    done = 1;
	}
    }
    if (r_info[desc].pos == GDO_REQ_SIZE) {
	tcp_read++;
	handle_request(desc);
    }
    else if (errno != EWOULDBLOCK) {
	clear_chan(desc);
    }
}

/*
 *	Name -		handle_recv()
 *	Purpose -	Read a request from the UDP socket.
 */
static void
handle_recv()
{
    unsigned char*	ptr = r_info[udp_desc].buf.b;
    struct sockaddr_in*	addr = &r_info[udp_desc].addr;
    int	len = sizeof(struct sockaddr_in);
    int	r;

    r = recvfrom(udp_desc, ptr, GDO_REQ_SIZE, 0, (void*)addr, &len);
    if (r == GDO_REQ_SIZE) {
	udp_read++;
	r_info[udp_desc].pos = GDO_REQ_SIZE;
	if (debug) {
	    fprintf(stderr, "recvfrom %s\n", inet_ntoa(addr->sin_addr));
	}
	handle_request(udp_desc);
    }
    else {
	if (debug) {
	    fprintf(stderr, "recvfrom returned %d - ", r);
	    perror("");
	}
	clear_chan(udp_desc);
    }
}

/*
 *	Name -		handle_request()
 *	Purpose -	Once we have read a full request, we come here
 *			to take action depending on the request type.
 */
static void
handle_request(int desc)
{
    unsigned char      type = r_info[desc].buf.r.rtype;
    unsigned char      size = r_info[desc].buf.r.nsize;
    unsigned char      ptype = r_info[desc].buf.r.ptype;
    unsigned long      port = ntohl(r_info[desc].buf.r.port);
    unsigned char      *buf = r_info[desc].buf.r.name;
    map_ent*		m;

    FD_CLR(desc, &read_fds);
    FD_SET(desc, &write_fds);
    w_info[desc].pos = 0;

    if (debug > 1) {
	if (desc == udp_desc) {
	    fprintf(stderr, "request type '%c' on UDP chan", type);
	}
	else {
	    fprintf(stderr, "request type '%c' from chan %d", type, desc);
	}
	fprintf(stderr, " - name: '%.*s' port: %d\n", size, buf, port);
    }

    if (ptype != GDO_TCP_GDO && ptype != GDO_TCP_FOREIGN &&
        ptype != GDO_UDP_GDO && ptype != GDO_UDP_FOREIGN) {
	if (ptype != 0 || (type != GDO_PROBE && type != GDO_PREPLY &&
	    type != GDO_SERVERS)) {
	    if (debug) {
		fprintf(stderr, "Illegal port type in request\n");
	    }
	    clear_chan(desc);
	    return;
	}
    }

    /*
     *	The default return value is a four byte number set to zero.
     *	We assume that malloc returns data aligned on a 4 byte boundary.
     */
    w_info[desc].len = 4;
    w_info[desc].buf = (char*)malloc(4);
    w_info[desc].buf[0] = 0;
    w_info[desc].buf[1] = 0;
    w_info[desc].buf[2] = 0;
    w_info[desc].buf[3] = 0;

    if (type == GDO_REGISTER) {
	/*
	 *	See if this is a request from a local process.
	 */
	if (is_local_host(r_info[desc].addr.sin_addr) == 0) {
	    fprintf(stderr, "Illegal attempt to register!\n");
	    clear_chan(desc);		/* Only local progs may register. */
	    return;
	}

	/*
	 *	What should we do if we already have the name registered?
	 *	Simple algorithm -
	 *		We check to see if we can bind to the old port,
	 *		and if we can we assume that the original process
	 *		has gone away and permit a new registration for the
	 *		same name.
	 *		This is not foolproof - if the machine has more
	 *		than one IP address, we could bind to the port on
	 *		one address even though the server is using it on
	 *		another.
	 *		Also - the operating system is not guaranteed to
	 *		let us bind to the port if another process has only
	 *		recently stopped using it.
	 *		Also - what if an old server used the port that the
	 *		new one is using?  In this case the registration
	 *		attempt will be refused even though it shouldn't be!
	 *		On the other hand - the occasional registration
	 *		failure MUST be better than permitting a process to
	 *		grab a name already in use! If a server fails to
	 *		register a name/port combination, it can always be
	 *		coded to retry on a different port.
	 */
	m = map_by_name(buf, size);
	if (m) {
	    int	sock = -1;

	    if ((ptype & GDO_NET_MASK) == GDO_NET_TCP) {
		sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	    }
	    else if ((ptype & GDO_NET_MASK) == GDO_NET_UDP) {
		sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	    }

	    if (sock < 0) {
		perror("unable to create new socket");
	    }
	    else {
		int	r = 1;
		if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,
			    (char*)&r, sizeof(r)) < 0) {
		    perror("unable to set socket options");
		}
		else {
		    struct sockaddr_in	sa;
		    int			result;
		    short			p = m->port;

		    mzero(&sa, sizeof(sa));
		    sa.sin_family = AF_INET;
		    sa.sin_addr.s_addr = htonl(INADDR_ANY);
		    sa.sin_port = htons(p);
		    result = bind(sock, (void*)&sa, sizeof(sa));
		    if (result == 0) {
			if (debug > 1) {
			    fprintf(stderr, "re-register from %d to %d\n",
				m->port, port);
			}
			m->port = port;
			m->net = (ptype & GDO_NET_MASK);
			m->svc = (ptype & GDO_SVC_MASK);
			port = htonl(m->port);
			*(unsigned long*)w_info[desc].buf = port;
		    }
		}
		close(sock);
	    }
	}
	else if (port == 0) {	/* Port not provided!	*/
	    fprintf(stderr, "port not provided in request\n");
	}
	else {		/* Use port provided in request.	*/
	    m = map_add(buf, size, port, ptype);
	    port = htonl(m->port);
	    *(unsigned long*)w_info[desc].buf = port;
	}
    }
    else if (type == GDO_LOOKUP) {
	m = map_by_name(buf, size);
	if (m != 0 && (m->net | m->svc) != ptype) {
	    if (debug > 1) {
		fprintf(stderr, "requested service is of wrong type\n");
	    }
	    m = 0;	/* Name exists but is of wrong type.	*/
	}
	if (m) {
	    int	sock = -1;

	    /*
	     *	We check to see if we can bind to the old port, and if we can
	     *	we assume that the process has gone away and remove it from
	     *	the map.
	     *	This is not foolproof - if the machine has more
	     *	than one IP address, we could bind to the port on
	     *	one address even though the server is using it on
	     *	another.
	     */
	    if ((ptype & GDO_NET_MASK) == GDO_NET_TCP) {
		sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	    }
	    else if ((ptype & GDO_NET_MASK) == GDO_NET_UDP) {
		sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	    }

	    if (sock < 0) {
		perror("unable to create new socket");
	    }
	    else {
		int	r = 1;
		if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,
			    (char*)&r, sizeof(r)) < 0) {
		    perror("unable to set socket options");
		}
		else {
		    struct sockaddr_in	sa;
		    int			result;
		    unsigned short	p = (unsigned short)m->port;

		    mzero(&sa, sizeof(sa));
		    sa.sin_family = AF_INET;
		    sa.sin_addr.s_addr = htonl(INADDR_ANY);
		    sa.sin_port = htons(p);
		    result = bind(sock, (void*)&sa, sizeof(sa));
		    if (result == 0) {
			map_del(m);
			m = 0;
		    }
		}
		close(sock);
	    }
	}
	if (m) {	/* Lookup found live server.	*/
	    *(unsigned long*)w_info[desc].buf = htonl(m->port);
	}
	else {		/* Not found.			*/
	    if (debug > 1) {
		fprintf(stderr, "requested service not found\n");
	    }
	    *(unsigned short*)w_info[desc].buf = 0;
	}
    }
    else if (type == GDO_UNREG) {
	/*
	 *	See if this is a request from a local process.
	 */
	if (is_local_host(r_info[desc].addr.sin_addr) == 0) {
	    fprintf(stderr, "Illegal attempt to un-register!\n");
	    clear_chan(desc);
	    return;
	}
	m = map_by_name(buf, size);
	if (m) {
	    if ((m->net | m->svc) != ptype) {
		if (debug) {
	            fprintf(stderr, "Attempt to unregister with wrong type\n");
		}
	    }
	    else {
		*(unsigned long*)w_info[desc].buf = htonl(m->port);
	        map_del(m);
	    }
	}
	else {
	    if (debug > 1) {
		fprintf(stderr, "requested service not found\n");
	    }
	}
    }
    else if (type == GDO_SERVERS) {
	int	i;

	free(w_info[desc].buf);
	w_info[desc].buf = (char*)malloc(4 + prb_used*sizeof(*prb));
	*(unsigned long*)w_info[desc].buf = htonl(prb_used);
	for (i = 0; i < prb_used; i++) {
	    mcopy(&w_info[desc].buf[4+i*IASIZE], prb[i], IASIZE);
	}
	w_info[desc].len = 4 + prb_used*IASIZE;
    }
    else if (type == GDO_PROBE) {
	/*
	 *	If the client is a name server, we add it to the list.
	 */
	if (r_info[desc].addr.sin_port == my_port) {
	    if (is_local_net(r_info[desc].addr.sin_addr)) {
		if (prb_get((struct in_addr*)&r_info[desc].buf.b[4]) == 0) {
		    prb_add((struct in_addr*)&r_info[desc].buf.b[4]);
		}
	    }
	}
	/*
	 *	For a UDP request from another name server, we send a reply
	 *	packet.  We shouldn't be getting probes from anywhere else,
	 *	but just to be nice, we send back our port number anyway.
	 */
	if (desc == udp_desc && r_info[desc].addr.sin_port == my_port) {
	    free(w_info[desc].buf);
	    w_info[desc].buf = (char*)malloc(GDO_REQ_SIZE);
	    mzero(w_info[desc].buf, GDO_REQ_SIZE);
	    w_info[desc].buf[0] = GDO_PREPLY;
	    w_info[desc].buf[1] = sizeof(my_addr);
	    w_info[desc].buf[2] = 0;
	    w_info[desc].buf[3] = 0;
	    mcopy(&w_info[desc].buf[4], &my_addr, sizeof(my_addr));
	    w_info[desc].len = GDO_REQ_SIZE;
	}
	else {
	    port = my_port;
	    *(unsigned long*)w_info[desc].buf = htonl(port);
	}
    }
    else if (type == GDO_PREPLY) {
	/*
	 *	This should really be a reply by UDP to a probe we sent
	 *	out earlier.  We should add the name server to our list.
	 */
	if (r_info[desc].addr.sin_port == my_port) {
	    if (is_local_net(r_info[desc].addr.sin_addr)) {
		if (prb_get((struct in_addr*)&r_info[desc].buf.b[4]) == 0) {
		    prb_add((struct in_addr*)&r_info[desc].buf.b[4]);
		}
	    }
	}
	/*
	 *	Because this is really a reply to us, we don't want to reply
	 *	to it or we would get a feedback loop.
	 */
	clear_chan(desc);
	return;
    }
    else {
	fprintf(stderr, "Illegal operation code received!\n");
	clear_chan(desc);
	return;
    }

    /*
     *	If the request was via UDP, we send a response back by queuing
     *	rather than letting the normal 'write_handler()' function do it.
     */
    if (desc == udp_desc) {
	queue_msg(&r_info[desc].addr, w_info[desc].buf, w_info[desc].len);
	clear_chan(desc);
    }
}

/*
 *	Name -		handle_send()
 *	Purpose -	Send any pending message on UDP socket.
 *			The code is designed to send the message in parts if
 *			the 'sendto()' function returns a positive integer
 *			indicating that only part of the message has been
 *			written.  This should never happen - but I coded it
 *			this way in case we have to run on a system which
 *			implements sendto() badly (I used such a system
 *			many years ago).
 */
static void
handle_send()
{
    struct u_data*	entry = u_queue;

    if (entry) {
	int	r;

	r = sendto(udp_desc, &entry->dat[entry->pos], entry->len - entry->pos,
			0, (void*)&entry->addr, sizeof(entry->addr));
	/*
	 *	'r' is the number of bytes sent. This should be the number
	 *	of bytes we asked to send, or -1 to indicate failure.
	 */
	if (r > 0) {
	    entry->pos += r;
	}

	/*
	 *	If we haven't written all the data, it should have been
	 *	because we blocked.  Anything else is a major problem
	 *	so we remove the message from the queue.
	 */
	if (entry->pos != entry->len) {
	    if (errno != EWOULDBLOCK) {
		if (debug) {
		    fprintf(stderr, "failed sendto for %s\n",
			    inet_ntoa(entry->addr.sin_addr));
		}
		u_queue = entry->next;
		free(entry->dat);
		free(entry);
	    }
	}
	else {
	    udp_sent++;
	    if (debug > 1) {
		fprintf(stderr, "performed sendto for %s\n",
				inet_ntoa(entry->addr.sin_addr));
	    }
	    /*
	     *	If we have sent the entire message - remove it from queue.
	     */
	    if (entry->pos == entry->len) {
		queue_pop();
	    }
	}
    }
}

/*
 *	Name -		handle_write()
 *	Purpose -	Write data to a channel.  When all writing for the
 *			channel is complete, close the channel down.
 *
 *			This is all probably totally paranoid - the reply
 *			to any request is so short that the write operation
 *			should not block so there shouldn't be any need to
 *			handle non-blocking I/O.
 */
static void
handle_write(int desc)
{
    char*	ptr = w_info[desc].buf;
    int		len = w_info[desc].len;
    int		r;

    r = write(desc, &ptr[w_info[desc].pos], len - w_info[desc].pos);
    if (r < 0) {
	if (debug > 1) {
	    fprintf(stderr, "Failed write on chan %d - closing\n", desc);
	}
	/*	
	 *	Failure - close connection silently.
	 */
	clear_chan(desc);
    }
    else {
	w_info[desc].pos += r;
	if (w_info[desc].pos >= len) {
	    tcp_sent++;
	    if (debug > 1) {
		fprintf(stderr, "Completed write on chan %d - closing\n", desc);
	    }
	    /*	
	     *	Success - written all information.
	     */
	    clear_chan(desc);
	}
    }
}


int
main(int argc, char** argv)
{
    char*	options = "Hdfp";
    int		c;

    while ((c = getopt(argc, argv, options)) != -1) {
	switch(c) {
	    case 'H':
		printf("%s -[%s]\n", argv[0], options);
		printf("GNU Distributed Objects name server\n");
		printf("-H		for help\n");
		printf("-d		Extra debug logging.\n");
		printf("-f		avoid fork() to make debugging easy\n");
		printf("-p		skip probe for unknown servers\n");
		printf("		NB. This may actually SLOW startup.\n");
		exit(0);

	    case 'd':
		debug++;
		break;

	    case 'f':
		nofork++;
		break;

	    case 'p':
		noprobe++;
		break;

	    default:
		printf("%s - GNU Distributed Objects name server\n", argv[0]);
		printf("-H	for help\n");
		exit(0);
	}
    }

    if (nofork == 0) {
	/*
	 *	Now fork off child process to run in background.
	 */
	switch (fork()) {
	    case -1:
		fprintf(stderr, "gdomap - fork failed - bye.\n");
		exit(1);

	    case 0:
		/*
		 *	Try to run in background.
		 */
#ifdef	NeXT
		setpgrp(0, getpid());
#else
		setsid();
#endif
		break;

	    default:
		if (debug) {
		    fprintf(stderr, "gdomap - initialisation complete.\n");
		}
		exit(0);
	}
    }

    /*
     *	Ensure we don't have any open file descriptors which may refer
     *	to sockets bound to ports we may try to use.
     *
     *	Use '/dev/tty' to produce logging output and use '/dev/null'
     *	for stdin and stdout.
     */
    for (c = 0; c < FD_SETSIZE; c++) {
	(void)close(c);
    }
    (void)open("/dev/null", O_RDONLY);	/* Stdin.	*/
    (void)open("/dev/null", O_WRONLY);	/* Stdout.	*/
    (void)open("/dev/tty", O_WRONLY);	/* Stderr.	*/

    init_iface();	/* Build up list of network interfaces.	*/
    init_ports();	/* Create ports to handle requests.	*/
    init_probe();	/* Probe other name servers on net.	*/

    if (debug) {
	fprintf(stderr, "gdomap - entering main loop.\n");
    }
    handle_io();
    return(0);
}

/*
 *	Name -		queue_probe()
 *	Purpose -	Send a probe request to a specified host so we
 *			can see if a name server is running on it.
 *			We don't bother to check to see if it worked.
 */
static void
queue_probe(struct in_addr* to, struct in_addr* from)
{
    struct sockaddr_in	sin;
    gdo_req	msg;

    if (debug > 2) {
        fprintf(stderr, "Probing for server on '%s'\n", inet_ntoa(*to));
    }
    mzero(&sin, sizeof(sin));
    sin.sin_family = AF_INET;
    mcopy(&sin.sin_addr, to, sizeof(*to));
    sin.sin_port = my_port;

    mzero((char*)&msg, GDO_REQ_SIZE);
    msg.rtype = GDO_PROBE;
    msg.nsize = sizeof(*from);
    msg.ptype = 0;
    msg.dummy = 0;
    msg.port = 0;
    mcopy(msg.name, &from, sizeof(*from));
  
    queue_msg(&sin, (unsigned char*)&msg, GDO_REQ_SIZE);
}

