# scripts
All scripts in this location are referenced for deployment automation

* boot.sh is invoked by CloudInit on each instance creation via Terraform.  It contains steps which perform inital bootstrapping of the instance prior to provisioning.
* boot_plus_tmp.sh is an alternate version of boot.sh which demonstrates configuring a RAID0 Block Volume array for use as /tmp.  This is useful for caching data when using Object Storage.
* cloudera_manager_boot.sh is a top level boot script for Cloudera Manager (Utility) instance.  This is required because subsequent scripts are too large to fit in metadata without compression.
* cms_mysql.sh is invoked by cloudinit on the Utility node to stand up Cloudera Manager and Pre-requisites using MySQL for Metadata. It is compressed and loaded into extended metadata.
* cms_postgres.sh is an older installaltion method using Postgres instead of MySQL for cluster metadata.  This is depracated.
* deploy_on_oci.py is the primary Python script invoked to deploy Cloudera EDH v6 using cm_client python libraries.  It is compressed and loaded into extended metdata.

# CloudInit boot scripts

With the introduction of local KDC for secure cluster, this requires some setup at the instance level as part of the bootstrapping process.  To facilitate local KDC, this automation is inserted into the Cloudera Manager CloudInit boot script.   There is also a dependency for krb5.conf on the cluster hosts, prior to enabling Cloudera Manager management of these Kerberos client files.  KDC setup depends on a few parameters which can be modified prior to deployment:

* boot.sh
  * kdc_server - This is the hostname where KDC is deployed (defaults to Cloudera Manager host)
  * realm - This is set to hadoop.com by default.
  * REALM - This is set to HADOOP.COM by default.
* cms_mysql.sh
  * KERBEROS_PASSWORD - This is used for the root/admin account.
  * SCM_USER_PASSWORD - By default the cloudera-scm user is given admin control of the KDC.  This is required for Cloudera Manager to setup and manage principals, and the password here is used by that account.
  * kdc_server - Defaults to local hostname.
  * realm - This is set to hadoop.com by default.  
  * REALM - This is set to HADOOP.COM by default.
* cms_postgres.sh - Same items as cm_boot_mysql.sh
* deploy_on_oci.py
  * realm - This is HADOOP.COM by default.
  * kdc_admin - Set to cloudera-scm@HADOOP.COM by default.
  * kdc_password - This should match what is set in the CM boot script for SCM_USER_PASSWORD.

It is highly suggested you modify at a minimum the default passwords prior to deployment.

## CAUTION WHEN MODIFYING BOOT SCRIPTS
Because boot.sh and cms_mysql.sh/cms_postgres.sh  are invoked as part of user_data and extended_metadata  in Terraform, if you modify these files and re-run a deployment, default behavior is existing instances will be destroyed and re-deployed because of this change.   
