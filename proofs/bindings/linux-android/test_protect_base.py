import unittest
import xml.etree.ElementTree as ET
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


spec = spec_from_file_location("protect_base", Path(__file__).with_name("protect-base.py"))
module = module_from_spec(spec)
spec.loader.exec_module(module)


class BaseProtectionTest(unittest.TestCase):
    def test_only_base_dac_label_is_overridden(self):
        root = ET.fromstring("""
        <domain type="kvm"><name>cairn-proof-offline</name><devices>
          <disk type="file" device="disk"><driver name="qemu" type="qcow2"/>
            <source file="/var/lib/libvirt/images/cairn-proof-offline/run.qcow2"/>
            <target dev="vda" bus="virtio"/>
          </disk>
        </devices><seclabel type="dynamic" model="selinux"/></domain>
        """)

        module.protect_base(root)

        disk = root.find("devices/disk")
        self.assertEqual(
            disk.find("backingStore/source").attrib,
            {"file": "/var/lib/libvirt/images/cairn-proof-offline/base.qcow2"},
        )
        self.assertEqual(
            disk.find("backingStore/source/seclabel").attrib,
            {"model": "dac", "relabel": "no"},
        )
        self.assertIsNotNone(disk.find("backingStore/backingStore"))
        self.assertEqual(root.find("seclabel").get("model"), "selinux")
        self.assertIsNone(disk.find("source/seclabel"))

    def test_unrelated_domain_is_rejected_without_mutation(self):
        root = ET.fromstring("<domain><name>unrelated</name><devices/></domain>")
        before = ET.tostring(root)

        with self.assertRaises(ValueError):
            module.protect_base(root)

        self.assertEqual(ET.tostring(root), before)

    def test_unexpected_resources_are_rejected_without_mutation(self):
        for resource in (
            '<interface type="network"/>',
            '<filesystem/>',
            '<hostdev/>',
            '<channel/>',
            '<disk device="cdrom"/>',
        ):
            with self.subTest(resource=resource):
                root = ET.fromstring(f"""
                <domain><name>cairn-proof-offline</name><devices>
                  <disk device="disk"><source
                    file="/var/lib/libvirt/images/cairn-proof-offline/run.qcow2"/>
                  </disk>{resource}
                </devices></domain>
                """)
                before = ET.tostring(root)

                with self.assertRaises(ValueError):
                    module.protect_base(root)

                self.assertEqual(ET.tostring(root), before)

    def test_wrong_path_or_existing_backing_store_is_rejected(self):
        for path, backing in (
            ("/unrelated.qcow2", ""),
            ("/var/lib/libvirt/images/cairn-proof-offline/run.qcow2", "<backingStore/>"),
        ):
            with self.subTest(path=path, backing=backing):
                root = ET.fromstring(f"""
                <domain><name>cairn-proof-offline</name><devices>
                  <disk device="disk"><source file="{path}"/>{backing}</disk>
                </devices></domain>
                """)
                before = ET.tostring(root)

                with self.assertRaises(ValueError):
                    module.protect_base(root)

                self.assertEqual(ET.tostring(root), before)


if __name__ == "__main__":
    unittest.main()
