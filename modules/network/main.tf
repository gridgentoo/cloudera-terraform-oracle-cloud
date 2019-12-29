variable "VPC-CIDR" {
  default = "10.0.0.0/16"
}

resource "oci_core_vcn" "cloudera_vcn" {
  cidr_block     = "${var.VPC-CIDR}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "cloudera_vcn"
  dns_label      = "cdhvcn"
}

resource "oci_core_internet_gateway" "cloudera_internet_gateway" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "cloudera_internet_gateway"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"
}

resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"
  display_name   = "nat_gateway"
}

resource "oci_core_service_gateway" "cloudera_service_gateway" {
    compartment_id = "${var.compartment_ocid}"
    services {
      service_id = "${lookup(data.oci_core_services.all_svcs_moniker.services[0], "id")}"
    }
    vcn_id = "${oci_core_vcn.cloudera_vcn.id}"
    display_name = "Cloudera Service Gateway"
}

resource "oci_core_route_table" "RouteForComplete" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"
  display_name   = "RouteTableForComplete"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "${oci_core_internet_gateway.cloudera_internet_gateway.id}"
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"
  display_name   = "private"

  route_rules = [
    {
      destination       = "${var.oci_service_gateway}"
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = "${oci_core_service_gateway.cloudera_service_gateway.id}"
    },
    {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = "${oci_core_nat_gateway.nat_gateway.id}"
    }
	
  ]
}

resource "oci_core_security_list" "PublicSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Public Subnet"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"

  egress_security_rules = [{
    destination = "0.0.0.0/0"
    protocol    = "6"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 7180
      "min" = 7180
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 18088
      "min" = 18088
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 19888
      "min" = 19888
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    protocol = "6"
    source   = "${var.VPC-CIDR}"
  }]
}

resource "oci_core_security_list" "PrivateSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Private"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"

  egress_security_rules = [{
    destination = "0.0.0.0/0"
    protocol    = "6"
  }]

  egress_security_rules = [{
    protocol    = "6"
    destination = "${var.VPC-CIDR}"
  }]

  ingress_security_rules = [{
    protocol = "6"
    source   = "${var.VPC-CIDR}"
  }]
}

resource "oci_core_security_list" "BastionSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Bastion"
  vcn_id         = "${oci_core_vcn.cloudera_vcn.id}"

  egress_security_rules = [{
    protocol    = "6"
    destination = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      protocol = "6"
      source   = "${var.VPC-CIDR}"
    },
  ]
}

resource "oci_core_subnet" "public" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
  cidr_block          = "${cidrsubnet(var.VPC-CIDR, 8, 1)}"
  display_name        = "public_${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.cloudera_vcn.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  security_list_ids   = ["${oci_core_security_list.PublicSubnet.id}"]
  dhcp_options_id     = "${oci_core_vcn.cloudera_vcn.default_dhcp_options_id}"
  dns_label           = "public${var.availability_domain}"
}

resource "oci_core_subnet" "private" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
  cidr_block          = "${cidrsubnet(var.VPC-CIDR, 8, 2)}"
  display_name        = "private_ad${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.cloudera_vcn.id}"
  route_table_id      = "${oci_core_route_table.private.id}"
  security_list_ids   = ["${oci_core_security_list.PrivateSubnet.id}"]
  dhcp_options_id     = "${oci_core_vcn.cloudera_vcn.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "true"
  dns_label = "private${var.availability_domain}"
}

resource "oci_core_subnet" "bastion" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
  cidr_block          = "${cidrsubnet(var.VPC-CIDR, 8, 3)}"
  display_name        = "bastion_ad${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.cloudera_vcn.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  security_list_ids   = ["${oci_core_security_list.BastionSubnet.id}"]
  dhcp_options_id     = "${oci_core_vcn.cloudera_vcn.default_dhcp_options_id}"
  dns_label           = "bastion${var.availability_domain}"
}
