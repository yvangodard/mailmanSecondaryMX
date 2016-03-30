mailmanSecondaryMX.sh
=====================

Présentation
------------

Cet outil est destiné à alimenter un serveur MX secondaire avec les adresses utilisées par l'outil Mailman en configuration avec domaines vrituels (cf. [GNU Mailman Virtual domains](http://www.list.org/mailman-install/postfix-virtual.html)).

Il va exporter la totalité de cette table, ou la filtrer en n'exportant que les entrées correspondant à un domaine particulier puis les déposer avec la commande `scp` sur le serveur MX secondaire et enfin lancer en SSH la commande `postmap` sur ce serveur secondaire.



Bug report
-------------

Si vous voulez me faire remonter un bug : [ouvrir un bug](https://github.com/ygodard/mailmanSecondaryMX/issues).


Pré-requis avant installation et utilisation
---------
### 1. Sur le serveur primaire sur lequel est exécuté l'outil `mailmanSecondaryMX.sh` 

- doit utiliser Mailman en configuration avec domaines vir``tuels (cf. [GNU Mailman Virtual domains](http://www.list.org/mailman-install/postfix-virtual.html))
- doit disposer d'un fichier `virtual_alias_maps` ou `relay_recipient_maps` pour Mailman correctement déclaré dans la configuration de Postfix (cf. `/etc/postfix/main.cf`), par exemple `relay_recipient_maps = hash:/var/lib/mailman/data/virtual-mailman`
- la table `virtual_alias_maps` ou `relay_recipient_maps` pour Mailman doit être alimentée (fichier non vide)
- le serveur MX primaire doit pouvoir accéder au serveur MX secondaire en SSH avec authentification par clé ([voir ici comment configurer les clés SSH] (https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2))

### 2. Sur le serveur MX secondaire :

- le ou les domaines relayés doivent être déclarés dans la configuration de Postfix dans la table transport (par défaut la table transport `/etc/postfix/transport`), par exemple : `domaine_relaye.com smtp:url_serveur_mx_primaire.domaine_relaye.com`
- le ou les domaines relayés doivent être déclarés dans la configuration de Postfix dans les `relay_domains` (par exemple : `relay_domains = domaine_relaye.com`)
- table spécifique contenant les adresses relayées doit être déclarée en tant que `relay_recipient_maps` (par défaut, l'outil utilise la table `/etc/postfix/mailmanSecondaryMX` mais vous pouvez utiliser un autre fichier si besoin - voir paramètres du script). 
Par exemple : `relay_recipient_maps = hash:/etc/postfix/mailmanSecondaryMX`



Installation
---------

Pour installer cet outil, téléchargez le script dans le dossier où vous voulez l'installer :

	wget --no-check-certificate https://raw.github.com/yvangodard/mailmanSecondaryMX/master/mailmanSecondaryMX.sh ; 
	sudo chmod 755 mailmanSecondaryMX.sh
	
Pour une aide complète, installez le script et lancez le :

    ./mailmanSecondaryMX.sh help



License
-------

Ce script `mailmanSecondaryMX.sh` de [Yvan GODARD](http://www.yvangodard.me) est mis à disposition selon les termes de la licence Creative Commons 4.0 BY NC SA (Attribution - Pas d’Utilisation Commerciale - Partage dans les Mêmes Conditions).

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0"><img alt="Licence Creative Commons" style="border-width:0" src="http://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a>


Limitations
-----------

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.