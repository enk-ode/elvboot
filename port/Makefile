# The FreeBSD port of elvboot. The checkout is the source: elebake stage
# rescue tool package writes the distfile as a git archive of the checkout
# (<name>-<version>.tar.gz into DISTDIR, VERSION substituted on the way
# out) and runs 'make makesum package' here with ELEBAKE_DISTVERSION in the environment, DISTDIR,
# WRKDIRPREFIX and PACKAGES of the stage. On the way to the ports tree the
# same file takes MASTER_SITES (or USE_GITHUB) and a committed distinfo.
PORTNAME=	elvboot
DISTVERSION=	${ELEBAKE_DISTVERSION:U0.0.0}	# from the environment: a command-line variable would travel in MAKEFLAGS into the dependency ports
CATEGORIES=	sysutils
MASTER_SITES=	# the distfile is placed into DISTDIR by the build

MAINTAINER=	dr.johannes.bruegmann@gmail.com
COMMENT=	Elevated boot: the compiler of a verified-boot trust chain
WWW=		https://github.com/enk-ode/elvboot

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

RUN_DEPENDS=	gpg:security/gnupg

NO_BUILD=	yes
NO_ARCH=	yes

# The checkout's own Makefile knows the layout ('make stage': the tool under
# lib/elebake, the wrapper in bin, the manual, the completion, the docs);
# the plist is read from what it staged.
do-install:
	@cd ${WRKSRC} && ${MAKE} stage PKGSTAGE=${STAGEDIR} PKGPREFIX=${PREFIX}

post-install:
	@cd ${STAGEDIR}${PREFIX} && ${FIND} . \( -type f -o -type l \) | ${SED} -e 's|^\./||' -e 's|^\(share/man/man[1-9]/.*\.[1-9]\)$$|\1.gz|' | ${SORT} >> ${TMPPLIST}

.include <bsd.port.mk>
