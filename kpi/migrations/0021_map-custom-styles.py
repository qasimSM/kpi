# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import migrations, models
import jsonfield.fields
import private_storage.fields
import kpi.models.import_export_task
import private_storage.storage.s3boto3
import kpi.fields


class Migration(migrations.Migration):

    dependencies = [
        ('kpi', '0020_add_validate_submissions_permission_to_asset'),
    ]

    operations = [
        migrations.AddField(
            model_name='asset',
            name='map_custom',
            field=kpi.fields.LazyDefaultJSONBField(default=dict),
        ),
        migrations.AddField(
            model_name='asset',
            name='map_styles',
            field=kpi.fields.LazyDefaultJSONBField(default=dict),
        ),
    ]
