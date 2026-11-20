{{- define "tripsplit.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels for one tier; call with (dict "ctx" $ "component" "api"). */}}
{{- define "tripsplit.selectorLabels" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "tripsplit.labels" -}}
{{ include "tripsplit.selectorLabels" . }}
app.kubernetes.io/part-of: {{ .ctx.Release.Name }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version }}
{{- end -}}

{{- define "tripsplit.secretName" -}}
{{- default (printf "%s-db" .Release.Name) .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "tripsplit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ include "tripsplit.fullname" . }}{{- else -}}default{{- end -}}
{{- end -}}

{{- define "tripsplit.dbHost" -}}
{{- default (printf "%s-postgres" .Release.Name) .Values.database.host -}}
{{- end -}}

{{/* The in-memory STOMP broker lives inside one JVM; refuse to scale until a broker relay exists. */}}
{{- define "tripsplit.validate" -}}
{{- $scaled := or .Values.api.autoscaling.enabled (gt (int .Values.api.replicaCount) 1) -}}
{{- if and $scaled (not .Values.api.scaleOutReady) -}}
{{- fail "trip-split: the API uses an in-memory STOMP broker; set api.scaleOutReady=true only after adding a broker relay" -}}
{{- end -}}
{{- end -}}

{{- define "tripsplit.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile: { type: RuntimeDefault }
{{- end -}}

{{- define "tripsplit.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities: { drop: [ALL] }
{{- end -}}
