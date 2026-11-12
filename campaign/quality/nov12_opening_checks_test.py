import copy
import json
from pathlib import Path
import tempfile
import unittest
from nov12_opening_checks import validate_receipt

class Receipts(unittest.TestCase):
    def test_negative_controls(self):
        baseline = json.loads((Path(__file__).parent / 'nov12_opening_layout/nov12_opening_route_60.json').read_text())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'receipt.json'
            self.assertTrue(validate_receipt(path, 60))
            path.write_text('{invalid')
            self.assertTrue(validate_receipt(path, 60))
            path.write_text(json.dumps(baseline))
            self.assertEqual(validate_receipt(path, 60), [])
            for key, value in [('passed',False),('passed',1),('hz',120),('deaths',1),('failures',['bad']),('source_drift',['bad']),('clinic_roof_crossed',False),('clinic_street_crossed',False),('objective_receipts',{}),('source_hashes',{})]:
                mutant=copy.deepcopy(baseline); mutant[key]=value
                path.write_text(json.dumps(mutant))
                self.assertTrue(validate_receipt(path,60),key)
            mutant=copy.deepcopy(baseline)
            mutant['objective_receipts']['city_clinic']['required_goals'][0]['completed']=False
            path.write_text(json.dumps(mutant));self.assertTrue(validate_receipt(path,60))
if __name__ == '__main__': unittest.main()
